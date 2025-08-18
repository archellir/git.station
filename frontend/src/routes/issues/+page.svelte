<script lang="ts">
	import SearchBar from '../SearchBar.svelte';
	import type { Issue, FilterState } from '$lib/types';
	import { IssueState, getLabelColor, COLORS } from '$lib/constants';
	
	// Mock issue data - will be replaced with API calls
	let issues: Issue[] = [
		{
			id: 1,
			title: 'Authentication session timeout not working correctly',
			body: 'Users are experiencing unexpected logouts during active sessions. The session timeout mechanism needs investigation.',
			state: IssueState.OPEN,
			author: 'security-team',
			assignee: 'backend-dev',
			labels: ['bug', 'security', 'high-priority'],
			createdAt: '2025-08-18T10:30:00Z',
			updatedAt: '2025-08-18T14:15:00Z',
			comments: 5,
			repository: 'git-station'
		},
		{
			id: 2,
			title: 'Add syntax highlighting for Zig language files',
			body: 'The code viewer currently doesn\'t support syntax highlighting for .zig files. Would be great to add support.',
			state: IssueState.OPEN,
			author: 'ui-architect',
			labels: ['enhancement', 'frontend', 'good-first-issue'],
			createdAt: '2025-08-17T16:22:00Z',
			updatedAt: '2025-08-17T16:22:00Z',
			comments: 2,
			repository: 'git-station'
		},
		{
			id: 3,
			title: 'Repository creation API returns 500 error',
			body: 'Creating repositories through the API endpoint fails with internal server error. Logs show SQLite connection issue.',
			state: IssueState.CLOSED,
			author: 'qa-tester',
			assignee: 'backend-team',
			labels: ['bug', 'api', 'resolved'],
			createdAt: '2025-08-16T09:15:00Z',
			updatedAt: '2025-08-17T11:45:00Z',
			comments: 8,
			repository: 'git-station'
		}
	];
	
	let searchQuery = $state('');
	let selectedState = $state<FilterState>('all');
	let selectedRepository = $state('All Repositories');
	let selectedLabel = $state('All Labels');
	
	let filteredIssues = $derived(
		issues.filter(issue => {
			const matchesSearch = issue.title.toLowerCase().includes(searchQuery.toLowerCase()) ||
								  issue.body.toLowerCase().includes(searchQuery.toLowerCase());
			const matchesState = selectedState === 'all' || issue.state === selectedState;
			const matchesRepo = selectedRepository === 'All Repositories' || issue.repository === selectedRepository;
			const matchesLabel = selectedLabel === 'All Labels' || issue.labels.includes(selectedLabel);
			
			return matchesSearch && matchesState && matchesRepo && matchesLabel;
		})
	);
	
	const allLabels = [...new Set(issues.flatMap(i => i.labels))];
	const allRepos = [...new Set(issues.map(i => i.repository))];
	
	
	function formatDate(dateString: string): string {
		return new Date(dateString).toLocaleDateString();
	}
</script>

<svelte:head>
	<title>Issues - Git Station</title>
</svelte:head>

<div class="space-y-6">
	<!-- Header -->
	<div class="cyber-bg-panel p-6 rounded-sm">
		<div class="flex flex-col lg:flex-row lg:items-center lg:justify-between space-y-4 lg:space-y-0">
			<div>
				<h1 class="text-3xl font-bold cyber-text-glow mb-2">
					<span class="text-neon-cyan">></span> Issue Tracker
				</h1>
				<p class="text-gray-400">
					<span class="text-neon-green font-mono">{issues.filter(i => i.state === IssueState.OPEN).length}</span> open •
					<span class="text-gray-300 font-mono">{issues.filter(i => i.state === IssueState.CLOSED).length}</span> closed •
					<span class="text-gray-300 font-mono">{issues.length}</span> total issues
				</p>
			</div>
			
			<div class="flex items-center space-x-4">
				<button class="cyber-button">
					<span class="mr-2">+</span>
					New Issue
				</button>
			</div>
		</div>
	</div>
	
	<!-- Filters -->
	<div class="cyber-bg-panel p-4 rounded-sm">
		<div class="flex flex-col lg:flex-row gap-4">
			<!-- Search -->
			<div class="flex-1">
				<SearchBar bind:value={searchQuery} placeholder="Search issues by title or description..." />
			</div>
			
			<!-- Filter Controls -->
			<div class="flex flex-wrap gap-2">
				<!-- State Filter -->
				<div class="flex border border-gray-700 rounded-sm overflow-hidden">
					<button
						onclick={() => selectedState = 'all'}
						class="px-4 py-2 text-sm transition-colors
							{selectedState === 'all' 
								? 'bg-glow-green-50 text-neon-green border-neon-green' 
								: 'text-gray-300 hover:text-neon-green hover:bg-glow-green-50'}"
					>
						All ({issues.length})
					</button>
					<button
						onclick={() => selectedState = IssueState.OPEN}
						class="px-4 py-2 text-sm border-l border-gray-700 transition-colors
							{selectedState === IssueState.OPEN 
								? 'bg-glow-green-50 text-neon-green border-neon-green' 
								: 'text-gray-300 hover:text-neon-green hover:bg-glow-green-50'}"
					>
						Open ({issues.filter(i => i.state === IssueState.OPEN).length})
					</button>
					<button
						onclick={() => selectedState = IssueState.CLOSED}
						class="px-4 py-2 text-sm border-l border-gray-700 transition-colors
							{selectedState === IssueState.CLOSED 
								? 'bg-glow-green-50 text-neon-green border-neon-green' 
								: 'text-gray-300 hover:text-neon-green hover:bg-glow-green-50'}"
					>
						Closed ({issues.filter(i => i.state === IssueState.CLOSED).length})
					</button>
				</div>
				
				<select bind:value={selectedRepository} class="cyber-input text-sm min-w-0">
					<option>All Repositories</option>
					{#each allRepos as repo}
						<option>{repo}</option>
					{/each}
				</select>
				
				<select bind:value={selectedLabel} class="cyber-input text-sm min-w-0">
					<option>All Labels</option>
					{#each allLabels as label}
						<option>{label}</option>
					{/each}
				</select>
			</div>
		</div>
	</div>
	
	<!-- Issues List -->
	<div class="space-y-4">
		{#each filteredIssues as issue}
			<div class="cyber-bg-panel p-6 rounded-sm hover:border-neon-green transition-colors">
				<div class="flex items-start space-x-4">
					<!-- State Indicator -->
					<div class="flex-shrink-0 mt-1">
						{#if issue.state === IssueState.OPEN}
							<div class="w-4 h-4 rounded-full bg-neon-green flex items-center justify-center" title="Open">
								<span class="text-xs text-black">●</span>
							</div>
						{:else}
							<div class="w-4 h-4 rounded-full bg-neon-purple flex items-center justify-center" title="Closed">
								<span class="text-xs text-black">✓</span>
							</div>
						{/if}
					</div>
					
					<!-- Issue Content -->
					<div class="flex-1 min-w-0">
						<!-- Title -->
						<h3 class="text-lg font-semibold mb-2 hover:text-neon-cyan transition-colors cursor-pointer">
							<a href="/issues/{issue.id}">
								{issue.title}
							</a>
						</h3>
						
						<!-- Description -->
						<p class="text-gray-400 text-sm mb-3 line-clamp-2">
							{issue.body}
						</p>
						
						<!-- Labels -->
						{#if issue.labels.length > 0}
							<div class="flex flex-wrap gap-2 mb-3">
								{#each issue.labels as label}
									<span class="px-2 py-1 text-xs rounded-sm border {getLabelColor(label)}">
										{label}
									</span>
								{/each}
							</div>
						{/if}
						
						<!-- Metadata -->
						<div class="flex flex-wrap items-center gap-4 text-xs text-gray-500">
							<span class="flex items-center space-x-1">
								<span>#</span>
								<span class="font-mono">{issue.id}</span>
							</span>
							
							<span class="flex items-center space-x-1">
								<span>opened by</span>
								<span class="font-mono text-neon-green">{issue.author}</span>
								<span>on {formatDate(issue.createdAt)}</span>
							</span>
							
							{#if issue.assignee}
								<span class="flex items-center space-x-1">
									<span>assigned to</span>
									<span class="font-mono text-neon-cyan">{issue.assignee}</span>
								</span>
							{/if}
							
							<span class="flex items-center space-x-1">
								<span>💬</span>
								<span>{issue.comments}</span>
							</span>
							
							<span class="flex items-center space-x-1">
								<span>📁</span>
								<span class="font-mono">{issue.repository}</span>
							</span>
						</div>
					</div>
				</div>
			</div>
		{:else}
			<div class="cyber-bg-panel p-12 rounded-sm text-center">
				<div class="text-4xl mb-4">🔍</div>
				<h3 class="text-xl font-semibold mb-2 text-gray-300">No issues found</h3>
				<p class="text-gray-500 mb-4">
					{#if searchQuery}
						No issues match your search criteria
					{:else}
						Adjust your filters to see more issues
					{/if}
				</p>
				<button class="cyber-button">
					Create Issue
				</button>
			</div>
		{/each}
	</div>
</div>

<style>
	.line-clamp-2 {
		display: -webkit-box;
		-webkit-line-clamp: 2;
		-webkit-box-orient: vertical;
		overflow: hidden;
	}
</style>