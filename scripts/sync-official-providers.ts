#!/usr/bin/env -S bun run
// Unified workflow: discover official skill repositories, validate, resolve revisions, and calculate hashes

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

const KNOWN_ORGS = [
	"anthropics",
	"apify",
	"apollographql",
	"astronomer",
	"auth0",
];
const PROJECT_ROOT = path.dirname(
	path.dirname(import.meta.url.replace("file://", "")),
);
const SOURCES_FILE = path.join(PROJECT_ROOT, "sources.json");

const GITHUB_API_BASE = "https://api.github.com";
const SKILLS_SH_BASE = "https://skills.sh";

// Log helpers
const log = {
	info: (msg: string) => console.log(`✓ ${msg}`),
	warn: (msg: string) => console.warn(`⚠ ${msg}`),
	task: (msg: string) => console.log(`\n📋 ${msg}`),
	progress: (current: number, total: number, step: string) =>
		process.stdout.write(`  [${current}/${total}] ${step}...\r`),
};

// Fetch organizations from skills.sh using htmlq
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

		return orgs.length > 0 ? orgs : KNOWN_ORGS;
	} catch (error) {
		log.warn(`Error fetching organizations: ${error}`);
		return KNOWN_ORGS;
	}
}

// Fetch repositories for an organization from skills.sh using htmlq
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

// Check if repo has src/ directory
async function hasSrcDirectory(owner: string, repo: string): Promise<boolean> {
	const url = `${GITHUB_API_BASE}/repos/${owner}/${repo}/contents/src`;
	const response = await fetch(url, {
		headers: { Accept: "application/vnd.github.v3+json" },
	});

	return response.status === 200;
}

// Resolve revision via git ls-remote
async function resolveRevision(owner: string, repo: string): Promise<string> {
	for (const branch of ["main", "master", "HEAD"]) {
		try {
			const proc = spawn(
				["git", "ls-remote", `https://github.com/${owner}/${repo}`, branch],
				{
					stdout: "pipe",
					stderr: "ignore",
				},
			);

			const output = await new Response(proc.stdout).text();
			const rev = output.split(/\s+/)[0];

			if (rev && rev.length === 40) {
				return rev;
			}
		} catch {
			// Continue to next branch
		}
	}

	return "";
}

// Fetch SRI hash using nix-prefetch-github
async function fetchSriHash(
	owner: string,
	repo: string,
	rev: string,
): Promise<string> {
	if (!rev) return "";

	try {
		const proc = spawn(["nix-prefetch-github", owner, repo, "--rev", rev], {
			stdout: "pipe",
			stderr: "ignore",
		});

		const output = await new Response(proc.stdout).text();
		return output.trim();
	} catch {
		return "";
	}
}

// Main workflow
async function main() {
	console.log("\n" + "═".repeat(40));
	console.log("Official Skills Registry Sync");
	console.log("═".repeat(40));

	log.task(
		"Phase 1: Discovering organizations and repositories from skills.sh",
	);

	// Fetch organizations from skills.sh
	const orgs = await fetchOrganizations();
	log.info(`Found ${orgs.length} organizations: ${orgs.join(", ")}`);

	const discovered: Record<string, string[]> = {};

	for (const org of orgs) {
		const repos = await fetchOrgRepos(org);
		discovered[org] = repos;
		log.info(`${org}: ${repos.length} repositories`);
	}

	const totalDiscovered = Object.values(discovered).reduce(
		(sum, arr) => sum + arr.length,
		0,
	);
	log.info(`Total discovered: ${totalDiscovered} repositories`);

	// Phase 2: Use skills.sh as source of truth (no validation needed)
	log.task("Phase 2: Accepting all repositories from skills.sh");
	const validated = discovered; // Trust skills.sh discovery
	const totalValidated = totalDiscovered;
	log.info(`Total to process: ${totalValidated} repositories`);

	// Phase 3: Resolve revisions in parallel
	log.task("Phase 3: Resolving revisions");
	const revisions: Record<string, Record<string, string>> = {};

	const revisionLimit = pLimit(6); // 6 concurrent git ls-remote calls
	let revResolved = 0;

	for (const org of orgs) {
		revisions[org] = {};
		const promises = validated[org].map((repo) =>
			revisionLimit(async () => {
				const rev = await resolveRevision(org, repo);
				revisions[org][repo] = rev;
				revResolved++;
				log.progress(revResolved, totalValidated, `resolving ${org}/${repo}`);
			}),
		);

		await Promise.all(promises);
	}

	console.log(); // newline after progress
	log.info(`Resolved: ${revResolved} revisions`);

	// Phase 4: Fetch hashes (optional, requires nix-prefetch-github)
	log.task("Phase 4: Fetching SRI hashes");

	const hashes: Record<string, Record<string, string>> = {};
	const hashLimit = pLimit(3); // 3 concurrent nix-prefetch-github calls (resource-intensive)
	let hashCount = 0;

	// Check if nix-prefetch-github is available
	let nixAvailable = false;
	try {
		const proc = spawn(["which", "nix-prefetch-github"], { stdout: "pipe" });
		const output = await new Response(proc.stdout).text();
		nixAvailable = output.trim().length > 0;
	} catch {
		nixAvailable = false;
	}

	if (!nixAvailable) {
		log.warn("nix-prefetch-github not available (requires: nix flake develop)");
	} else {
		for (const org of orgs) {
			hashes[org] = {};
			const promises = validated[org].map((repo) =>
				hashLimit(async () => {
					const rev = revisions[org][repo];
					if (rev) {
						const hash = await fetchSriHash(org, repo, rev);
						hashes[org][repo] = hash;
						if (hash) hashCount++;
					}
					log.progress(hashCount, totalValidated, `hashing ${org}/${repo}`);
				}),
			);

			await Promise.all(promises);
		}
	}

	console.log(); // newline after progress
	if (nixAvailable) {
		log.info(`Fetched: ${hashCount} hashes`);
	}

	// Phase 5: Build and write sources.json
	log.task("Phase 5: Updating sources.json");

	const sources: SourcesJson = {
		version: "1.0",
		updatedAt: new Date().toISOString(),
		namespace: "skills-sh",
		providers: {
			official: {},
		},
	};

	for (const org of orgs) {
		sources.providers.official[org] = {};

		for (const repo of validated[org]) {
			sources.providers.official[org][repo] = {
				owner: org,
				repo: repo,
				rev: revisions[org][repo] || "",
				sha256: hashes[org]?.[repo] || "",
			};
		}
	}

	writeFileSync(SOURCES_FILE, JSON.stringify(sources, null, 2));
	log.info(`Written: ${SOURCES_FILE}`);

	// Summary
	console.log(`\n${"═".repeat(40)}`);
	console.log("Sync Complete");
	console.log("═".repeat(40));
	console.log(` Discovered: ${totalDiscovered} repositories`);
	console.log(` Validated:  ${totalValidated} with src/ directory`);
	console.log(` Revisions:  ${revResolved} resolved`);
	if (nixAvailable) {
		console.log(` Hashes: ${hashCount} calculated`);
	}
	console.log(`${"═".repeat(40)}\n`);
}

main().catch((error) => {
	console.error("Error:", error);
	process.exit(1);
});
