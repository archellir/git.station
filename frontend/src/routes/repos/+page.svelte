<script lang="ts">
	import RepositoryCard from '../RepositoryCard.svelte';
	import SearchBar from '../SearchBar.svelte';
	import CreateRepositoryModal from '$lib/components/CreateRepositoryModal.svelte';
	import CyberButton from '$lib/components/CyberButton.svelte';
	import { goto } from '$app/navigation';
	import { page } from '$app/stores';
	import { onMount } from 'svelte';
	
	// Mock repository data - will be replaced with API calls
	let repositories = [
		{
			name: 'awesome-project',
			description: 'A cyberpunk-themed web application with neon aesthetics and terminal-inspired interface design',
			language: 'TypeScript',
			stars: 42,
			forks: 7,
			lastCommit: '2 hours ago',
			status: 'active' as const
		},
		{
			name: 'neural-network',
			description: 'Machine learning algorithms for future prediction and data analysis',
			language: 'Python',
			stars: 156,
			forks: 23,
			lastCommit: '1 day ago',
			status: 'active' as const
		},
		{
			name: 'quantum-compiler',
			description: 'Next-generation compiler for quantum computing applications',
			language: 'Rust',
			stars: 89,
			forks: 12,
			lastCommit: '3 days ago',
			status: 'archived' as const
		},
		{
			name: 'blockchain-protocol',
			description: 'Decentralized protocol for secure transactions',
			language: 'Go',
			stars: 234,
			forks: 45,
			lastCommit: '5 hours ago',
			status: 'active' as const
		},
		{
			name: 'ai-assistant',
			description: 'Intelligent virtual assistant with natural language processing',
			language: 'Python',
			stars: 67,
			forks: 18,
			lastCommit: '1 week ago',
			status: 'active' as const
		}
	];
	
	let searchQuery = $state('');
	let selectedLanguage = $state('All Languages');
	let selectedStatus = $state('All Status');
	
	let filteredRepos = $derived(
		repositories.filter(repo => {
			const matchesSearch = repo.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
								  repo.description.toLowerCase().includes(searchQuery.toLowerCase());
			const matchesLanguage = selectedLanguage === 'All Languages' || repo.language === selectedLanguage;
			const matchesStatus = selectedStatus === 'All Status' || repo.status === selectedStatus.toLowerCase();
			
			return matchesSearch && matchesLanguage && matchesStatus;
		})
	);
	
	let sortBy = $state('name');
	let sortOrder = $state<'asc' | 'desc'>('asc');
	
	let sortedRepos = $derived(
		[...filteredRepos].sort((a, b) => {
			let comparison = 0;
			switch (sortBy) {
				case 'name':
					comparison = a.name.localeCompare(b.name);
					break;
				case 'stars':
					comparison = a.stars - b.stars;
					break;
				case 'language':
					comparison = a.language.localeCompare(b.language);
					break;
				case 'updated':
					// Simplified comparison for demo
					comparison = a.lastCommit.localeCompare(b.lastCommit);
					break;
			}
			return sortOrder === 'desc' ? -comparison : comparison;
		})
	);
	
	const languages = [...new Set(repositories.map(r => r.language))];
	
	// Modal state
	let showCreateModal = $state(false);
	
	function handleRepositoryCreated(repoName: string) {
		// Refresh the repositories list (in a real app, this would refetch from API)
		// For now, just navigate to the new repository
		goto(`/repos/${repoName}`);
	}
	
	// Check for new=true query parameter to auto-open modal
	onMount(() => {
		const urlParams = new URLSearchParams($page.url.search);
		if (urlParams.get('new') === 'true') {
			showCreateModal = true;
			// Remove the query parameter from URL
			goto('/repos', { replaceState: true });
		}
	});
</script>

<svelte:head>
	<title>Repositories - Git Station</title>
</svelte:head>

<div class="space-y-6">
	<!-- Header -->
	<div class="cyber-bg-panel p-6 rounded-sm">
		<div class="flex flex-col lg:flex-row lg:items-center lg:justify-between space-y-4 lg:space-y-0">
			<div>
				<h1 class="text-3xl font-bold cyber-text-glow mb-2">
					<span class="text-neon-cyan">></span> Repository Archive
				</h1>
				<p class="text-gray-400">
					Browsing <span class="text-neon-green font-mono">{sortedRepos.length}</span> of 
					<span class="text-neon-green font-mono">{repositories.length}</span> repositories
				</p>
			</div>
			
			<div class="flex items-center space-x-3">
				<CyberButton
					size="lg"
					onclick={() => showCreateModal = true}
					icon="+"
				>
					Initialize Repository
				</CyberButton>
				<CyberButton
					variant="secondary"
					icon="📥"
				>
					Import Existing
				</CyberButton>
			</div>
		</div>
	</div>
	
	<!-- Search and Filters -->
	<div class="cyber-bg-panel p-4 rounded-sm">
		<div class="flex flex-col lg:flex-row gap-4">
			<!-- Search -->
			<div class="flex-1">
				<SearchBar bind:value={searchQuery} placeholder="Search repositories by name or description..." />
			</div>
			
			<!-- Filters -->
			<div class="flex flex-wrap gap-2">
				<select bind:value={selectedLanguage} class="cyber-input text-sm min-w-0">
					<option>All Languages</option>
					{#each languages as language}
						<option>{language}</option>
					{/each}
				</select>
				
				<select bind:value={selectedStatus} class="cyber-input text-sm min-w-0">
					<option>All Status</option>
					<option>Active</option>
					<option>Archived</option>
				</select>
				
				<select bind:value={sortBy} class="cyber-input text-sm min-w-0">
					<option value="name">Sort by Name</option>
					<option value="stars">Sort by Stars</option>
					<option value="language">Sort by Language</option>
					<option value="updated">Sort by Updated</option>
				</select>
				
				<CyberButton
					size="sm"
					onclick={() => sortOrder = sortOrder === 'asc' ? 'desc' : 'asc'}
					title={sortOrder === 'asc' ? 'Sort Descending' : 'Sort Ascending'}
				>
					{sortOrder === 'asc' ? '↓' : '↑'}
				</CyberButton>
			</div>
		</div>
		
		<!-- Active Filters -->
		{#if searchQuery || selectedLanguage !== 'All Languages' || selectedStatus !== 'All Status'}
			<div class="flex flex-wrap gap-2 mt-4 pt-4 border-t border-gray-700">
				<span class="text-xs text-gray-400 uppercase font-mono">Active Filters:</span>
				
				{#if searchQuery}
					<span class="inline-flex items-center gap-1 px-2 py-1 bg-glow-green-50 border border-neon-green text-neon-green text-xs rounded-sm">
						Search: "{searchQuery}"
						<CyberButton size="xs" variant="text" onclick={() => searchQuery = ''} class="hover:text-neon-cyan ml-1">✕</CyberButton>
					</span>
				{/if}
				
				{#if selectedLanguage !== 'All Languages'}
					<span class="inline-flex items-center gap-1 px-2 py-1 bg-glow-cyan-50 border border-neon-cyan text-neon-cyan text-xs rounded-sm">
						Language: {selectedLanguage}
						<CyberButton size="xs" variant="text" onclick={() => selectedLanguage = 'All Languages'} class="hover:text-neon-green ml-1">✕</CyberButton>
					</span>
				{/if}
				
				{#if selectedStatus !== 'All Status'}
					<span class="inline-flex items-center gap-1 px-2 py-1 bg-glow-pink-50 border border-neon-pink text-neon-pink text-xs rounded-sm">
						Status: {selectedStatus}
						<CyberButton size="xs" variant="text" onclick={() => selectedStatus = 'All Status'} class="hover:text-neon-green ml-1">✕</CyberButton>
					</span>
				{/if}
				
				<CyberButton
					variant="text"
					size="xs"
					onclick={() => {
						searchQuery = '';
						selectedLanguage = 'All Languages';
						selectedStatus = 'All Status';
					}}
				>
					Clear all
				</CyberButton>
			</div>
		{/if}
	</div>
	
	<!-- Repository Grid -->
	<div class="grid gap-6 md:grid-cols-2 xl:grid-cols-3">
		{#each sortedRepos as repo}
			<RepositoryCard {repo} />
		{:else}
			<div class="col-span-full text-center py-12">
				<div class="cyber-bg-panel p-8 rounded-sm inline-block">
					<div class="text-4xl mb-4">🔍</div>
					<h3 class="text-xl font-semibold mb-2 text-gray-300">No repositories found</h3>
					<p class="text-gray-500 mb-4">
						{#if searchQuery}
							No repositories match your search criteria
						{:else}
							Adjust your filters to see more repositories
						{/if}
					</p>
					<CyberButton
						onclick={() => {
							searchQuery = '';
							selectedLanguage = 'All Languages';
							selectedStatus = 'All Status';
						}}
					>
						Reset Filters
					</CyberButton>
				</div>
			</div>
		{/each}
	</div>
	
	<!-- Stats Footer -->
	<div class="cyber-bg-panel p-4 rounded-sm">
		<div class="grid grid-cols-2 md:grid-cols-4 gap-4 text-center">
			<div>
				<div class="text-2xl font-mono text-neon-green">{repositories.length}</div>
				<div class="text-xs text-gray-400 uppercase">Total Repos</div>
			</div>
			<div>
				<div class="text-2xl font-mono text-neon-cyan">{repositories.filter(r => r.status === 'active').length}</div>
				<div class="text-xs text-gray-400 uppercase">Active</div>
			</div>
			<div>
				<div class="text-2xl font-mono text-terminal-amber">{repositories.filter(r => r.status === 'archived').length}</div>
				<div class="text-xs text-gray-400 uppercase">Archived</div>
			</div>
			<div>
				<div class="text-2xl font-mono text-neon-purple">{languages.length}</div>
				<div class="text-xs text-gray-400 uppercase">Languages</div>
			</div>
		</div>
	</div>
</div>

<!-- Create Repository Modal -->
<CreateRepositoryModal bind:isOpen={showCreateModal} onRepositoryCreated={handleRepositoryCreated} />