<script lang="ts">
	import { page } from '$app/stores';
	import FileTree from './FileTree.svelte';
	import CommitHistory from './CommitHistory.svelte';
	import CodeViewer from './CodeViewer.svelte';
	
	let repoName = $derived($page.params.name);
	let currentBranch = $state('main');
	let currentPath = $state('');
	let activeTab = $state<'files' | 'commits' | 'branches' | 'issues' | 'pulls'>('files');
	let selectedFile = $state<string | null>(null);
	
	// Mock data - will be replaced with API calls
	let repository = $derived({
		name: repoName,
		description: 'A cyberpunk-themed web application with neon aesthetics',
		language: 'TypeScript',
		stars: 42,
		forks: 7,
		issues: 3,
		pullRequests: 2,
		branches: ['main', 'develop', 'feature/auth', 'hotfix/security'],
		lastCommit: '2 hours ago',
		status: 'active',
		size: '2.3 MB',
		license: 'MIT'
	});
	
	let branches = $derived(repository.branches);
	
	let tabs = $derived([
		{ id: 'files', label: 'Files', icon: '📁', count: null },
		{ id: 'commits', label: 'Commits', icon: '🔄', count: '156' },
		{ id: 'branches', label: 'Branches', icon: '🌿', count: branches.length.toString() },
		{ id: 'issues', label: 'Issues', icon: '⚠', count: repository.issues.toString() },
		{ id: 'pulls', label: 'Pull Requests', icon: '⇄', count: repository.pullRequests.toString() }
	] as const);
</script>

<svelte:head>
	<title>{repoName} - Git Station</title>
</svelte:head>

<div class="space-y-6">
	<!-- Repository Header -->
	<div class="cyber-bg-panel p-6 rounded-sm">
		<div class="flex flex-col lg:flex-row lg:items-center lg:justify-between space-y-4 lg:space-y-0">
			<div class="flex-1 min-w-0">
				<div class="flex items-center space-x-2 mb-2">
					<h1 class="text-2xl font-bold cyber-text-glow">
						<span class="text-neon-cyan">></span> {repository.name}
					</h1>
					<span class="inline-flex items-center px-2 py-1 text-xs bg-glow-green-50 border border-neon-green text-neon-green rounded-sm">
						{repository.status.toUpperCase()}
					</span>
				</div>
				
				<p class="text-gray-400 mb-4">{repository.description}</p>
				
				<div class="flex flex-wrap gap-4 text-sm text-gray-400">
					<div class="flex items-center space-x-1">
						<span class="w-3 h-3 rounded-full bg-blue-400"></span>
						<span>{repository.language}</span>
					</div>
					<div class="flex items-center space-x-1">
						<span class="text-neon-yellow">⭐</span>
						<span>{repository.stars}</span>
					</div>
					<div class="flex items-center space-x-1">
						<span class="text-neon-cyan">⑃</span>
						<span>{repository.forks}</span>
					</div>
					<div class="flex items-center space-x-1">
						<span>📊</span>
						<span>{repository.size}</span>
					</div>
					<div class="flex items-center space-x-1">
						<span>📄</span>
						<span>{repository.license}</span>
					</div>
				</div>
			</div>
			
			<div class="flex items-center space-x-3">
				<select bind:value={currentBranch} class="cyber-input text-sm">
					{#each branches as branch}
						<option value={branch}>🌿 {branch}</option>
					{/each}
				</select>
				
				<button class="cyber-button">
					<span class="mr-2">↪</span>
					Clone
				</button>
				
				<button class="cyber-button">
					<span class="mr-2">💾</span>
					Download
				</button>
				
				<button class="cyber-button">
					<span class="mr-2">⚙</span>
					Settings
				</button>
			</div>
		</div>
	</div>
	
	<!-- Navigation Tabs -->
	<div class="cyber-bg-panel rounded-sm">
		<div class="flex overflow-x-auto">
			{#each tabs as tab}
				<button
					onclick={() => {
						activeTab = tab.id;
						selectedFile = null;
					}}
					class="flex items-center space-x-2 px-6 py-4 font-medium text-sm uppercase tracking-wider transition-all duration-200
						{activeTab === tab.id 
							? 'bg-glow-green-50 text-neon-green border-b-2 border-neon-green' 
							: 'text-gray-400 hover:text-neon-green hover:bg-glow-green-50'}"
				>
					<span>{tab.icon}</span>
					<span>{tab.label}</span>
					{#if tab.count}
						<span class="px-2 py-1 bg-cyber-gray text-xs rounded-sm font-mono">{tab.count}</span>
					{/if}
				</button>
			{/each}
		</div>
	</div>
	
	<!-- Tab Content -->
	<div class="grid gap-6">
		{#if activeTab === 'files'}
			<div class="grid lg:grid-cols-3 gap-6">
				<!-- File Tree -->
				<div class="lg:col-span-1">
					<div class="cyber-bg-panel p-4 rounded-sm">
						<h3 class="font-semibold mb-4 cyber-text-glow">
							<span class="text-neon-purple">></span> File Explorer
						</h3>
						<FileTree bind:selectedFile branch={currentBranch} />
					</div>
				</div>
				
				<!-- Code Viewer -->
				<div class="lg:col-span-2">
					{#if selectedFile}
						<CodeViewer file={selectedFile} />
					{:else}
						<div class="cyber-bg-panel p-8 rounded-sm text-center">
							<div class="text-4xl mb-4">📂</div>
							<h3 class="text-xl font-semibold mb-2 text-gray-300">Select a file to view</h3>
							<p class="text-gray-500">Choose a file from the explorer to see its contents</p>
						</div>
					{/if}
				</div>
			</div>
		{:else if activeTab === 'commits'}
			<CommitHistory branch={currentBranch} />
		{:else if activeTab === 'branches'}
			<div class="cyber-bg-panel p-6 rounded-sm">
				<div class="flex items-center justify-between mb-6">
					<h3 class="text-xl font-semibold cyber-text-glow">
						<span class="text-neon-purple">></span> Branches
					</h3>
					<button class="cyber-button">
						<span class="mr-2">+</span>
						New Branch
					</button>
				</div>
				
				<div class="space-y-3">
					{#each branches as branch}
						<div class="flex items-center justify-between p-4 cyber-bg-dark rounded-sm border border-gray-700">
							<div class="flex items-center space-x-3">
								<span class="text-neon-green">🌿</span>
								<span class="font-mono {branch === currentBranch ? 'text-neon-green font-semibold' : 'text-gray-300'}">{branch}</span>
								{#if branch === currentBranch}
									<span class="px-2 py-1 bg-glow-green-50 border border-neon-green text-neon-green text-xs rounded-sm">CURRENT</span>
								{/if}
							</div>
							
							<div class="flex items-center space-x-2">
								{#if branch !== currentBranch}
									<button onclick={() => currentBranch = branch} class="cyber-button text-xs">
										Switch
									</button>
								{/if}
								{#if branch !== 'main'}
									<button class="cyber-button text-xs">
										Delete
									</button>
								{/if}
							</div>
						</div>
					{/each}
				</div>
			</div>
		{:else if activeTab === 'issues'}
			<div class="cyber-bg-panel p-6 rounded-sm">
				<div class="flex items-center justify-between mb-6">
					<h3 class="text-xl font-semibold cyber-text-glow">
						<span class="text-neon-purple">></span> Issues
					</h3>
					<button class="cyber-button">
						<span class="mr-2">+</span>
						New Issue
					</button>
				</div>
				
				<div class="text-center py-8">
					<div class="text-4xl mb-4">⚠</div>
					<h4 class="text-lg font-semibold mb-2 text-gray-300">No issues found</h4>
					<p class="text-gray-500 mb-4">Create your first issue to track bugs and feature requests</p>
					<button class="cyber-button">
						Create Issue
					</button>
				</div>
			</div>
		{:else if activeTab === 'pulls'}
			<div class="cyber-bg-panel p-6 rounded-sm">
				<div class="flex items-center justify-between mb-6">
					<h3 class="text-xl font-semibold cyber-text-glow">
						<span class="text-neon-purple">></span> Pull Requests
					</h3>
					<button class="cyber-button">
						<span class="mr-2">+</span>
						New Pull Request
					</button>
				</div>
				
				<div class="text-center py-8">
					<div class="text-4xl mb-4">⇄</div>
					<h4 class="text-lg font-semibold mb-2 text-gray-300">No pull requests</h4>
					<p class="text-gray-500 mb-4">Create a pull request to propose changes</p>
					<button class="cyber-button">
						Create Pull Request
					</button>
				</div>
			</div>
		{/if}
	</div>
</div>