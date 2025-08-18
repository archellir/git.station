<script lang="ts">
	import type { Repository } from '$lib/types';
	import { getLanguageColor, REPOSITORY_STATUS_COLORS, COLORS } from '$lib/constants';
	import { RepositoryStatus } from '$lib/constants';
	
	let { repo }: { repo: Repository } = $props();
</script>

<article class="cyber-card p-6 rounded-sm h-full flex flex-col">
	<!-- Header -->
	<div class="flex items-start justify-between mb-4">
		<div class="flex-1 min-w-0">
			<h3 class="font-semibold text-lg mb-1 cyber-text-glow">
				<a href="/repos/{repo.name}" class="hover:text-neon-cyan transition-colors">
					{repo.name}
				</a>
			</h3>
			<p class="text-gray-400 text-sm line-clamp-2">
				{repo.description}
			</p>
		</div>
		
		<div class="ml-4 flex items-center space-x-1">
			<span class="text-xs {REPOSITORY_STATUS_COLORS[repo.status]}">●</span>
			<span class="text-xs text-gray-500 uppercase font-mono">{repo.status}</span>
		</div>
	</div>
	
	<!-- Language -->
	<div class="flex items-center space-x-2 mb-4">
		<span class="w-3 h-3 rounded-full border {getLanguageColor(repo.language)} border-current bg-current bg-opacity-20"></span>
		<span class="text-sm {getLanguageColor(repo.language)} font-mono">{repo.language}</span>
	</div>
	
	<!-- Stats -->
	<div class="flex items-center justify-between text-sm text-gray-400 mt-auto">
		<div class="flex items-center space-x-4">
			<div class="flex items-center space-x-1">
				<span class="text-neon-yellow">⭐</span>
				<span class="font-mono">{repo.stars}</span>
			</div>
			<div class="flex items-center space-x-1">
				<span class="text-neon-cyan">⑃</span>
				<span class="font-mono">{repo.forks}</span>
			</div>
		</div>
		
		<div class="text-xs">
			<span class="text-gray-500">Updated</span>
			<span class="font-mono text-gray-300">{repo.lastCommit}</span>
		</div>
	</div>
	
	<!-- Action Buttons -->
	<div class="flex gap-2 mt-4 pt-4 border-t border-gray-700">
		<button class="cyber-button text-xs flex-1">
			<span class="mr-1">📁</span>
			Browse
		</button>
		<button class="cyber-button text-xs">
			<span class="mr-1">↪</span>
			Clone
		</button>
		<button class="cyber-button text-xs">
			<span class="mr-1">⚙</span>
			Settings
		</button>
	</div>
</article>

<style>
	.line-clamp-2 {
		display: -webkit-box;
		-webkit-line-clamp: 2;
		-webkit-box-orient: vertical;
		overflow: hidden;
	}
</style>