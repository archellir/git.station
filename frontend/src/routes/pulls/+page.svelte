<script lang="ts">
	import SearchBar from '../SearchBar.svelte';
	
	interface PullRequest {
		id: number;
		title: string;
		body: string;
		state: 'open' | 'closed' | 'merged';
		author: string;
		reviewers: string[];
		sourceBranch: string;
		targetBranch: string;
		repository: string;
		createdAt: string;
		updatedAt: string;
		comments: number;
		commits: number;
		additions: number;
		deletions: number;
		filesChanged: number;
		labels: string[];
	}
	
	// Mock PR data - will be replaced with API calls
	let pullRequests: PullRequest[] = [
		{
			id: 1,
			title: 'feat(ui): implement dark mode toggle functionality',
			body: 'Adds a dark mode toggle to the application settings. Includes proper theme persistence and system preference detection.',
			state: 'open',
			author: 'ui-architect',
			reviewers: ['tech-lead', 'ux-designer'],
			sourceBranch: 'feature/dark-mode',
			targetBranch: 'main',
			repository: 'git-station',
			createdAt: '2025-08-17T14:30:00Z',
			updatedAt: '2025-08-18T10:15:00Z',
			comments: 7,
			commits: 12,
			additions: 245,
			deletions: 32,
			filesChanged: 8,
			labels: ['enhancement', 'frontend', 'ui']
		},
		{
			id: 2,
			title: 'fix(auth): resolve session cleanup on logout',
			body: 'Fixes issue where user sessions were not properly cleaned up on logout, causing memory leaks in long-running instances.',
			state: 'merged',
			author: 'backend-team',
			reviewers: ['security-team'],
			sourceBranch: 'hotfix/session-cleanup',
			targetBranch: 'main',
			repository: 'git-station',
			createdAt: '2025-08-16T09:45:00Z',
			updatedAt: '2025-08-17T16:22:00Z',
			comments: 4,
			commits: 3,
			additions: 67,
			deletions: 23,
			filesChanged: 2,
			labels: ['bug', 'security', 'hotfix']
		},
		{
			id: 3,
			title: 'refactor(api): extract common response handlers',
			body: 'Refactors the API layer to use common response handlers, reducing code duplication and improving maintainability.',
			state: 'closed',
			author: 'backend-dev',
			reviewers: ['tech-lead'],
			sourceBranch: 'refactor/response-handlers',
			targetBranch: 'develop',
			repository: 'git-station',
			createdAt: '2025-08-15T11:20:00Z',
			updatedAt: '2025-08-16T14:10:00Z',
			comments: 12,
			commits: 8,
			additions: 156,
			deletions: 203,
			filesChanged: 15,
			labels: ['refactor', 'api', 'maintenance']
		}
	];
	
	let searchQuery = $state('');
	let selectedState = $state<'all' | 'open' | 'closed' | 'merged'>('all');
	let selectedRepository = $state('All Repositories');
	let selectedAuthor = $state('All Authors');
	
	let filteredPRs = $derived(
		pullRequests.filter(pr => {
			const matchesSearch = pr.title.toLowerCase().includes(searchQuery.toLowerCase()) ||
								  pr.body.toLowerCase().includes(searchQuery.toLowerCase());
			const matchesState = selectedState === 'all' || pr.state === selectedState;
			const matchesRepo = selectedRepository === 'All Repositories' || pr.repository === selectedRepository;
			const matchesAuthor = selectedAuthor === 'All Authors' || pr.author === selectedAuthor;
			
			return matchesSearch && matchesState && matchesRepo && matchesAuthor;
		})
	);
	
	const allRepos = [...new Set(pullRequests.map(pr => pr.repository))];
	const allAuthors = [...new Set(pullRequests.map(pr => pr.author))];
	
	function getStateColor(state: string): string {
		switch (state) {
			case 'open': return 'text-neon-green bg-green-900/20 border-neon-green';
			case 'merged': return 'text-neon-purple bg-purple-900/20 border-neon-purple';
			case 'closed': return 'text-terminal-red bg-red-900/20 border-terminal-red';
			default: return 'text-gray-400 bg-gray-900/20 border-gray-400';
		}
	}
	
	function getStateIcon(state: string): string {
		switch (state) {
			case 'open': return '⇄';
			case 'merged': return '✓';
			case 'closed': return '✕';
			default: return '?';
		}
	}
	
	function getLabelColor(label: string): string {
		const colors: Record<string, string> = {
			'enhancement': 'text-neon-green bg-green-900/20 border-neon-green',
			'bug': 'text-terminal-red bg-red-900/20 border-terminal-red',
			'frontend': 'text-neon-cyan bg-cyan-900/20 border-neon-cyan',
			'ui': 'text-neon-pink bg-pink-900/20 border-neon-pink',
			'security': 'text-neon-purple bg-purple-900/20 border-neon-purple',
			'hotfix': 'text-terminal-amber bg-yellow-900/20 border-terminal-amber',
			'refactor': 'text-gray-300 bg-gray-900/20 border-gray-300',
			'api': 'text-neon-cyan bg-cyan-900/20 border-neon-cyan',
			'maintenance': 'text-gray-400 bg-gray-900/20 border-gray-400'
		};
		return colors[label] || 'text-gray-400 bg-gray-900/20 border-gray-400';
	}
	
	function formatDate(dateString: string): string {
		return new Date(dateString).toLocaleDateString();
	}
</script>

<svelte:head>
	<title>Pull Requests - Git Station</title>
</svelte:head>

<div class="space-y-6">
	<!-- Header -->
	<div class="cyber-bg-panel p-6 rounded-sm">
		<div class="flex flex-col lg:flex-row lg:items-center lg:justify-between space-y-4 lg:space-y-0">
			<div>
				<h1 class="text-3xl font-bold cyber-text-glow mb-2">
					<span class="text-neon-cyan">></span> Pull Requests
				</h1>
				<p class="text-gray-400">
					<span class="text-neon-green font-mono">{pullRequests.filter(pr => pr.state === 'open').length}</span> open •
					<span class="text-neon-purple font-mono">{pullRequests.filter(pr => pr.state === 'merged').length}</span> merged •
					<span class="text-terminal-red font-mono">{pullRequests.filter(pr => pr.state === 'closed').length}</span> closed
				</p>
			</div>
			
			<div class="flex items-center space-x-4">
				<button class="cyber-button">
					<span class="mr-2">+</span>
					New Pull Request
				</button>
			</div>
		</div>
	</div>
	
	<!-- Filters -->
	<div class="cyber-bg-panel p-4 rounded-sm">
		<div class="flex flex-col lg:flex-row gap-4">
			<!-- Search -->
			<div class="flex-1">
				<SearchBar bind:value={searchQuery} placeholder="Search pull requests by title or description..." />
			</div>
			
			<!-- Filter Controls -->
			<div class="flex flex-wrap gap-2">
				<!-- State Filter -->
				<div class="flex border border-gray-700 rounded-sm overflow-hidden">
					<button
						onclick={() => selectedState = 'all'}
						class="px-3 py-2 text-sm transition-colors
							{selectedState === 'all' 
								? 'bg-glow-green-50 text-neon-green border-neon-green' 
								: 'text-gray-300 hover:text-neon-green hover:bg-glow-green-50'}"
					>
						All
					</button>
					<button
						onclick={() => selectedState = 'open'}
						class="px-3 py-2 text-sm border-l border-gray-700 transition-colors
							{selectedState === 'open' 
								? 'bg-glow-green-50 text-neon-green border-neon-green' 
								: 'text-gray-300 hover:text-neon-green hover:bg-glow-green-50'}"
					>
						Open
					</button>
					<button
						onclick={() => selectedState = 'merged'}
						class="px-3 py-2 text-sm border-l border-gray-700 transition-colors
							{selectedState === 'merged' 
								? 'bg-glow-green-50 text-neon-green border-neon-green' 
								: 'text-gray-300 hover:text-neon-green hover:bg-glow-green-50'}"
					>
						Merged
					</button>
					<button
						onclick={() => selectedState = 'closed'}
						class="px-3 py-2 text-sm border-l border-gray-700 transition-colors
							{selectedState === 'closed' 
								? 'bg-glow-green-50 text-neon-green border-neon-green' 
								: 'text-gray-300 hover:text-neon-green hover:bg-glow-green-50'}"
					>
						Closed
					</button>
				</div>
				
				<select bind:value={selectedRepository} class="cyber-input text-sm min-w-0">
					<option>All Repositories</option>
					{#each allRepos as repo}
						<option>{repo}</option>
					{/each}
				</select>
				
				<select bind:value={selectedAuthor} class="cyber-input text-sm min-w-0">
					<option>All Authors</option>
					{#each allAuthors as author}
						<option>{author}</option>
					{/each}
				</select>
			</div>
		</div>
	</div>
	
	<!-- Pull Requests List -->
	<div class="space-y-4">
		{#each filteredPRs as pr}
			<div class="cyber-bg-panel p-6 rounded-sm hover:border-neon-green transition-colors">
				<div class="flex items-start space-x-4">
					<!-- State Indicator -->
					<div class="flex-shrink-0 mt-1">
						<div class="w-6 h-6 rounded-sm border flex items-center justify-center {getStateColor(pr.state)}">
							<span class="text-sm">{getStateIcon(pr.state)}</span>
						</div>
					</div>
					
					<!-- PR Content -->
					<div class="flex-1 min-w-0">
						<!-- Title and State -->
						<div class="flex items-center space-x-2 mb-2">
							<h3 class="text-lg font-semibold hover:text-neon-cyan transition-colors cursor-pointer">
								<a href="/pulls/{pr.id}">
									{pr.title}
								</a>
							</h3>
							<span class="px-2 py-1 text-xs rounded-sm border {getStateColor(pr.state)} uppercase">
								{pr.state}
							</span>
						</div>
						
						<!-- Description -->
						<p class="text-gray-400 text-sm mb-3 line-clamp-2">
							{pr.body}
						</p>
						
						<!-- Branch Info -->
						<div class="flex items-center space-x-2 mb-3 text-sm">
							<span class="font-mono text-neon-green">{pr.sourceBranch}</span>
							<span class="text-gray-500">→</span>
							<span class="font-mono text-neon-cyan">{pr.targetBranch}</span>
						</div>
						
						<!-- Labels -->
						{#if pr.labels.length > 0}
							<div class="flex flex-wrap gap-2 mb-3">
								{#each pr.labels as label}
									<span class="px-2 py-1 text-xs rounded-sm border {getLabelColor(label)}">
										{label}
									</span>
								{/each}
							</div>
						{/if}
						
						<!-- Stats -->
						<div class="flex flex-wrap items-center gap-4 text-xs text-gray-500 mb-3">
							<span class="flex items-center space-x-1">
								<span class="text-neon-green">+{pr.additions}</span>
								<span class="text-terminal-red">-{pr.deletions}</span>
							</span>
							
							<span class="flex items-center space-x-1">
								<span>📄</span>
								<span>{pr.filesChanged} files</span>
							</span>
							
							<span class="flex items-center space-x-1">
								<span>🔄</span>
								<span>{pr.commits} commits</span>
							</span>
							
							<span class="flex items-center space-x-1">
								<span>💬</span>
								<span>{pr.comments} comments</span>
							</span>
						</div>
						
						<!-- Metadata -->
						<div class="flex flex-wrap items-center gap-4 text-xs text-gray-500">
							<span class="flex items-center space-x-1">
								<span>#</span>
								<span class="font-mono">{pr.id}</span>
							</span>
							
							<span class="flex items-center space-x-1">
								<span>opened by</span>
								<span class="font-mono text-neon-green">{pr.author}</span>
								<span>on {formatDate(pr.createdAt)}</span>
							</span>
							
							{#if pr.reviewers.length > 0}
								<span class="flex items-center space-x-1">
									<span>reviewers:</span>
									{#each pr.reviewers as reviewer, i}
										<span class="font-mono text-neon-cyan">{reviewer}{i < pr.reviewers.length - 1 ? ',' : ''}</span>
									{/each}
								</span>
							{/if}
							
							<span class="flex items-center space-x-1">
								<span>📁</span>
								<span class="font-mono">{pr.repository}</span>
							</span>
						</div>
					</div>
					
					<!-- Actions -->
					{#if pr.state === 'open'}
						<div class="flex flex-col gap-2">
							<button class="cyber-button text-xs">
								Review
							</button>
							<button class="cyber-button text-xs">
								Merge
							</button>
						</div>
					{/if}
				</div>
			</div>
		{:else}
			<div class="cyber-bg-panel p-12 rounded-sm text-center">
				<div class="text-4xl mb-4">⇄</div>
				<h3 class="text-xl font-semibold mb-2 text-gray-300">No pull requests found</h3>
				<p class="text-gray-500 mb-4">
					{#if searchQuery}
						No pull requests match your search criteria
					{:else}
						Create your first pull request to propose changes
					{/if}
				</p>
				<button class="cyber-button">
					Create Pull Request
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