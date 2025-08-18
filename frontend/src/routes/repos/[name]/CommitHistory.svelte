<script lang="ts">
	import type { Commit } from '$lib/types';
	import { getCommitTypeColor } from '$lib/constants';
	
	let { branch }: { branch: string } = $props();
	
	// Mock commit data - will be replaced with API calls
	let commits = [
		{
			hash: 'a3f5c2e',
			fullHash: 'a3f5c2e8d7b1f9c4e6a8b2d3f5c7e9a1b3d5f7c9',
			message: 'feat(ui): add cyberpunk theme with neon accents',
			author: 'cyber-dev',
			timestamp: '2 hours ago',
			date: '2025-08-18T15:30:00Z',
			additions: 42,
			deletions: 8,
			files: 5
		},
		{
			hash: 'b7e9d4f',
			fullHash: 'b7e9d4f1c3a5e7f9b1d3c5e7f9a1b3d5c7e9f1a3',
			message: 'fix(auth): resolve session timeout issue',
			author: 'security-team',
			timestamp: '6 hours ago',
			date: '2025-08-18T11:15:00Z',
			additions: 15,
			deletions: 23,
			files: 3
		},
		{
			hash: '1c8f3a9',
			fullHash: '1c8f3a9e5b7d2f4c6e8a0b2d4f6c8e0a2b4d6f8c',
			message: 'refactor(components): extract reusable button component',
			author: 'ui-architect',
			timestamp: '1 day ago',
			date: '2025-08-17T14:22:00Z',
			additions: 28,
			deletions: 45,
			files: 8
		},
		{
			hash: '9e2b7d4',
			fullHash: '9e2b7d4f8c1a3e5d7f9b1c3e5d7f9b1c3e5d7f9b',
			message: 'docs(readme): update installation instructions',
			author: 'tech-writer',
			timestamp: '2 days ago',
			date: '2025-08-16T10:45:00Z',
			additions: 12,
			deletions: 3,
			files: 1
		},
		{
			hash: '5f1a8c3',
			fullHash: '5f1a8c3e7b9d1f3c5e7a9b1d3f5c7e9a1b3d5f7c',
			message: 'feat(api): implement repository management endpoints',
			author: 'backend-team',
			timestamp: '3 days ago',
			date: '2025-08-15T16:30:00Z',
			additions: 156,
			deletions: 12,
			files: 12
		}
	];
	
	let selectedCommit = $state<string | null>(null);
	
	
	function copyCommitHash(hash: string) {
		navigator.clipboard.writeText(hash);
	}
</script>

<div class="cyber-bg-panel p-6 rounded-sm">
	<div class="flex items-center justify-between mb-6">
		<h3 class="text-xl font-semibold cyber-text-glow">
			<span class="text-neon-purple">></span> Commit History
		</h3>
		<div class="flex items-center space-x-2 text-sm">
			<span class="text-gray-400">Branch:</span>
			<span class="text-neon-green font-mono">{branch}</span>
		</div>
	</div>
	
	<div class="space-y-4">
		{#each commits as commit}
			<div class="cyber-bg-dark p-4 rounded-sm border border-gray-700 hover:border-neon-green transition-colors">
				<div class="flex items-start justify-between">
					<div class="flex-1 min-w-0">
						<!-- Commit Message -->
						<div class="flex items-center space-x-2 mb-2">
							<h4 class="font-medium {getCommitTypeColor(commit.message)} text-sm">
								{commit.message}
							</h4>
						</div>
						
						<!-- Commit Info -->
						<div class="flex flex-wrap items-center gap-4 text-xs text-gray-400">
							<div class="flex items-center space-x-1">
								<span>👤</span>
								<span class="font-mono">{commit.author}</span>
							</div>
							
							<div class="flex items-center space-x-1">
								<span>🕐</span>
								<span>{commit.timestamp}</span>
							</div>
							
							<div class="flex items-center space-x-1">
								<span class="text-neon-green">+{commit.additions}</span>
								<span class="text-terminal-red">-{commit.deletions}</span>
							</div>
							
							<div class="flex items-center space-x-1">
								<span>📁</span>
								<span>{commit.files} file{commit.files !== 1 ? 's' : ''}</span>
							</div>
						</div>
					</div>
					
					<!-- Commit Hash and Actions -->
					<div class="flex items-center space-x-2 ml-4">
						<button
							onclick={() => copyCommitHash(commit.fullHash)}
							class="font-mono text-xs bg-cyber-gray px-2 py-1 rounded-sm hover:bg-glow-green-50 hover:text-neon-green transition-colors"
							title="Copy full hash"
						>
							{commit.hash}
						</button>
						
						<button
							onclick={() => selectedCommit = selectedCommit === commit.hash ? null : commit.hash}
							class="cyber-button text-xs"
						>
							{selectedCommit === commit.hash ? 'Hide' : 'Details'}
						</button>
					</div>
				</div>
				
				<!-- Expanded Details -->
				{#if selectedCommit === commit.hash}
					<div class="mt-4 pt-4 border-t border-gray-700">
						<div class="grid md:grid-cols-2 gap-4 text-sm">
							<div class="space-y-2">
								<div class="flex justify-between">
									<span class="text-gray-400">Full Hash:</span>
									<span class="font-mono text-neon-cyan">{commit.fullHash}</span>
								</div>
								<div class="flex justify-between">
									<span class="text-gray-400">Author:</span>
									<span class="font-mono text-gray-300">{commit.author}</span>
								</div>
								<div class="flex justify-between">
									<span class="text-gray-400">Date:</span>
									<span class="font-mono text-gray-300">{new Date(commit.date).toLocaleString()}</span>
								</div>
							</div>
							
							<div class="space-y-2">
								<div class="flex justify-between">
									<span class="text-gray-400">Changes:</span>
									<span class="font-mono">
										<span class="text-neon-green">+{commit.additions}</span> 
										<span class="text-terminal-red">-{commit.deletions}</span>
									</span>
								</div>
								<div class="flex justify-between">
									<span class="text-gray-400">Files:</span>
									<span class="font-mono text-gray-300">{commit.files}</span>
								</div>
								<div class="flex justify-between">
									<span class="text-gray-400">Branch:</span>
									<span class="font-mono text-neon-green">{branch}</span>
								</div>
							</div>
						</div>
						
						<div class="flex gap-2 mt-4">
							<button class="cyber-button text-xs">
								<span class="mr-1">👁</span>
								View Changes
							</button>
							<button class="cyber-button text-xs">
								<span class="mr-1">🌿</span>
								Create Branch
							</button>
							<button class="cyber-button text-xs">
								<span class="mr-1">🔄</span>
								Revert
							</button>
						</div>
					</div>
				{/if}
			</div>
		{/each}
	</div>
	
	<!-- Load More -->
	<div class="text-center mt-6">
		<button class="cyber-button">
			<span class="mr-2">⬇</span>
			Load More Commits
		</button>
	</div>
</div>