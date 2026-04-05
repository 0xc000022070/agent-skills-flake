#!/usr/bin/env -S bun run
// Sync official providers: discover + fetch rev+sha256 in one call via nix-prefetch-github

import { writeFileSync } from "node:fs";
import path from "node:path";
import { spawn } from "bun";
import pLimit from "p-limit";

interface Repo {
	owner: string;
	repo: string;
	rev: string;
	sha256: string;
}

interface SourcesJson {
	version: string;
	updatedAt: string;
	namespace: string;
	providers: {
		official: Record<string, Record<string, Repo>>;
	};
}

const PROJECT_ROOT = path.dirname(
	path.dirname(import.meta.url.replace("file://", "")),
);
const SOURCES_FILE = path.join(PROJECT_ROOT, "sources.json");
const SKILLS_SH_BASE = "https://skills.sh";

const log = {
	info: (msg: string) => console.log(`✓ ${msg}`),
	warn: (msg: string) => console.warn(`⚠ ${msg}`),
	task: (msg: string) => console.log(`\n📋 ${msg}`),
	progress: (current: number, total: number, step: string) =>
		process.stdout.write(`  [${current}/${total}] ${step}...\r`),
};

async function fetchOrganizations(): Promise<string[]> {
	try {
		const proc = spawn(
			[
				"bash",
				"-c",
				`curl -s '${SKILLS_SH_BASE}/official' --compressed -H 'User-Agent: Mozilla/5.0 (X11; Linux x86_64; rv:149.0) Gecko/20100101 Firefox/149.0' | htmlq 'a.group span.font-semibold' --text`,
			],
			{ stdout: "pipe", stderr: "pipe" },
		);

		const output = await new Response(proc.stdout).text();
		const orgs = output
			.split("\n")
			.map((line) => line.trim())
			.filter(Boolean);

		return orgs;
	} catch (error) {
		log.warn(`Error fetching organizations: ${error}`);
		return [];
	}
}

async function fetchOrgRepos(org: string): Promise<string[]> {
	try {
		const proc = spawn(
			[
				"bash",
				"-c",
				`curl -s '${SKILLS_SH_BASE}/${org}' --compressed -H 'User-Agent: Mozilla/5.0 (X11; Linux x86_64; rv:149.0) Gecko/20100101 Firefox/149.0' | htmlq 'h3.font-semibold' --text`,
			],
			{ stdout: "pipe", stderr: "pipe" },
		);

		const output = await new Response(proc.stdout).text();
		const repos = output
			.split("\n")
			.map((line) => line.trim())
			.filter(Boolean);

		return repos;
	} catch (error) {
		log.warn(`Error fetching repos for ${org}: ${error}`);
		return [];
	}
}

// nix-prefetch-github returns: rev\nsha256
async function fetchHashWithRev(
	owner: string,
	repo: string,
): Promise<{ rev: string; sha256: string }> {
	try {
		const proc = spawn(["nix-prefetch-github", owner, repo], {
			stdout: "pipe",
			stderr: "pipe",
		});

		const output = await new Response(proc.stdout).text();
		const lines = output.trim().split("\n");

		const rev = lines[0]?.trim() || "";
		const sha256 = lines[1]?.trim() || "";

		return { rev, sha256 };
	} catch {
		return { rev: "", sha256: "" };
	}
}

async function main() {
	console.log("\n" + "═".repeat(40));
	console.log("Sync Official Providers");
	console.log("═".repeat(40));

	// Phase 1: Discover
	log.task("Phase 1: Discovering organizations");
	const orgs = await fetchOrganizations();

	if (orgs.length === 0) {
		log.warn("No organizations found");
		return;
	}

	log.info(`Found ${orgs.length} organizations`);

	// Phase 2: Discover repos
	log.task("Phase 2: Discovering repositories");
	const discovered: Record<string, string[]> = {};
	let totalRepos = 0;

	for (const org of orgs) {
		const repos = await fetchOrgRepos(org);
		discovered[org] = repos;
		totalRepos += repos.length;
		log.info(`${org}: ${repos.length} repos`);
	}

	log.info(`Total: ${totalRepos} repositories`);

	// Phase 3: Fetch hashes
	log.task("Phase 3: Fetching revisions and hashes");

	const limit = pLimit(3); // 3 concurrent nix-prefetch-github calls
	let processed = 0;

	const hashResults: Record<
		string,
		Record<string, { rev: string; sha256: string }>
	> = {};

	for (const org of orgs) {
		hashResults[org] = {};

		const promises = discovered[org].map((repo) =>
			limit(async () => {
				const hash = await fetchHashWithRev(org, repo);
				hashResults[org][repo] = hash;
				processed++;
				log.progress(processed, totalRepos, `${org}/${repo}`);
			}),
		);

		await Promise.all(promises);
	}

	console.log(); // newline after progress

	// Phase 4: Build sources.json
	log.task("Phase 4: Building sources.json");

	const sources: SourcesJson = {
		version: "1.0",
		updatedAt: new Date().toISOString(),
		namespace: "skills-sh",
		providers: {
			official: {},
		},
	};

	let withRev = 0;
	let withHash = 0;

	for (const org of orgs) {
		sources.providers.official[org] = {};

		for (const repo of discovered[org]) {
			const hash = hashResults[org][repo] || { rev: "", sha256: "" };

			if (hash.rev) withRev++;
			if (hash.sha256) withHash++;

			sources.providers.official[org][repo] = {
				owner: org,
				repo: repo,
				rev: hash.rev,
				sha256: hash.sha256,
			};
		}
	}

	writeFileSync(SOURCES_FILE, JSON.stringify(sources, null, 2));
	log.info(`Written: ${SOURCES_FILE}`);

	// Summary
	console.log(`\n${"═".repeat(40)}`);
	console.log("Sync Complete");
	console.log("═".repeat(40));
	console.log(`  Discovered: ${totalRepos} repositories`);
	console.log(
		`  With Rev:   ${withRev} (${((withRev / totalRepos) * 100).toFixed(1)}%)`,
	);
	console.log(
		`  With Hash:  ${withHash} (${((withHash / totalRepos) * 100).toFixed(1)}%)`,
	);
	console.log(`${"═".repeat(40)}\n`);
}

main().catch((error) => {
	console.error("Error:", error);
	process.exit(1);
});
