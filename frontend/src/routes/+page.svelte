<script lang="ts">
	import RepositoryCard from './RepositoryCard.svelte';
	import SearchBar from './SearchBar.svelte';
	
	// Mock data for now - will be replaced with API calls
	let repositories = [
		{
			name: 'awesome-project',
			description: 'A cyberpunk-themed web application with neon aesthetics',
			language: 'TypeScript',
			stars: 42,
			forks: 7,
			lastCommit: '2 hours ago',
			status: 'active'
		},
		{
			name: 'neural-network',
			description: 'Machine learning algorithms for future prediction',
			language: 'Python',
			stars: 156,
			forks: 23,
			lastCommit: '1 day ago',
			status: 'active'
		},
		{
			name: 'quantum-compiler',
			description: 'Next-generation compiler for quantum computing',
			language: 'Rust',
			stars: 89,
			forks: 12,
			lastCommit: '3 days ago',
			status: 'archived'
		}
	];
	
	let searchQuery = $state('');
	let filteredRepos = $derived(
		repositories.filter(repo => 
			repo.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
			repo.description.toLowerCase().includes(searchQuery.toLowerCase())
		)
	);
</script>

<svelte:head>
	<title>Dashboard - Git Station</title>
</svelte:head>

<div class="space-y-8">
	<!-- Header Section -->
	<div class="cyber-bg-panel p-6 rounded-sm">
		<div class="flex flex-col md:flex-row md:items-center md:justify-between space-y-4 md:space-y-0">
			<div>
				<h1 class="text-3xl font-bold cyber-text-glow mb-2">
					<span class="text-neon-cyan">></span> System Dashboard
				</h1>
				<p class="text-gray-400">
					Managing <span class="text-neon-green font-mono">{repositories.length}</span> repositories
					• <span class="text-terminal-amber font-mono">SECURE_CONNECTION_ACTIVE</span>
				</p>
			</div>
			
			<div class="flex items-center space-x-4">
				<div class="cyber-bg-dark px-4 py-2 rounded-sm border border-gray-700">
					<div class="flex items-center space-x-2 text-xs">
						<span class="text-terminal-green">●</span>
						<span class="text-gray-400">SYSTEM STATUS:</span>
						<span class="text-terminal-green font-mono">ONLINE</span>
					</div>
				</div>
				
				<button class="cyber-button">
					<span class="mr-2">+</span>
					Initialize Repository
				</button>
			</div>
		</div>
	</div>
	
	<!-- Search and Filters -->
	<div class="flex flex-col md:flex-row gap-4">
		<div class="flex-1">
			<SearchBar bind:value={searchQuery} placeholder="Search repositories..." />
		</div>
		
		<div class="flex gap-2">
			<select class="cyber-input text-sm">
				<option>All Languages</option>
				<option>TypeScript</option>
				<option>Python</option>
				<option>Rust</option>
				<option>JavaScript</option>
			</select>
			
			<select class="cyber-input text-sm">
				<option>All Status</option>
				<option>Active</option>
				<option>Archived</option>
			</select>
		</div>
	</div>
	
	<!-- Repository Grid -->
	<div class="grid gap-6 md:grid-cols-2 lg:grid-cols-3">
		{#each filteredRepos as repo}
			<RepositoryCard {repo} />
		{:else}
			<div class="col-span-full text-center py-12">
				<div class="cyber-bg-panel p-8 rounded-sm inline-block">
					<div class="text-4xl mb-4">🔍</div>
					<h3 class="text-xl font-semibold mb-2 text-gray-300">No repositories found</h3>
					<p class="text-gray-500 mb-4">
						{searchQuery ? `No results for "${searchQuery}"` : 'No repositories available'}
					</p>
					{#if !searchQuery}
						<button class="cyber-button">
							Create your first repository
						</button>
					{/if}
				</div>
			</div>
		{/each}
	</div>
	
	<!-- System Info Panel -->
	<div class="cyber-bg-panel p-6 rounded-sm">
		<h2 class="text-lg font-semibold mb-4 cyber-text-glow">
			<span class="text-neon-purple">></span> System Information
		</h2>
		
		<div class="grid grid-cols-2 md:grid-cols-4 gap-4 text-sm">
			<div class="cyber-bg-dark p-4 rounded-sm border border-gray-700">
				<div class="text-gray-400 mb-1">REPOSITORIES</div>
				<div class="text-2xl font-mono text-neon-green">{repositories.length}</div>
			</div>
			
			<div class="cyber-bg-dark p-4 rounded-sm border border-gray-700">
				<div class="text-gray-400 mb-1">TOTAL COMMITS</div>
				<div class="text-2xl font-mono text-neon-cyan">1,337</div>
			</div>
			
			<div class="cyber-bg-dark p-4 rounded-sm border border-gray-700">
				<div class="text-gray-400 mb-1">ACTIVE SESSIONS</div>
				<div class="text-2xl font-mono text-terminal-amber">1</div>
			</div>
			
			<div class="cyber-bg-dark p-4 rounded-sm border border-gray-700">
				<div class="text-gray-400 mb-1">UPTIME</div>
				<div class="text-2xl font-mono text-neon-purple">99.9%</div>
			</div>
		</div>
	</div>
</div>
