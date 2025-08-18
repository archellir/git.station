<script lang="ts">
	import { page } from '$app/stores';
	
	let currentPath = $derived($page.url.pathname);
	
	const navItems = [
		{ href: '/', label: 'Dashboard', icon: '⬢' },
		{ href: '/repos', label: 'Repositories', icon: '📁' },
		{ href: '/issues', label: 'Issues', icon: '⚠' },
		{ href: '/pulls', label: 'Pull Requests', icon: '⇄' }
	];
</script>

<nav class="cyber-bg-panel border-b border-gray-700">
	<div class="container mx-auto px-4">
		<div class="flex items-center justify-between h-16">
			<!-- Logo -->
			<div class="flex items-center space-x-4">
				<h1 class="text-2xl font-bold cyber-text-glow">
					<span class="text-neon-green">></span>
					<span class="terminal-cursor">Git Station</span>
				</h1>
			</div>
			
			<!-- Navigation Links -->
			<div class="hidden md:flex items-center space-x-1">
				{#each navItems as item}
					<a 
						href={item.href}
						class="px-4 py-2 rounded-sm transition-all duration-200 font-medium text-sm uppercase tracking-wider
							{currentPath === item.href 
								? 'bg-glow-green-50 text-neon-green cyber-border-glow' 
								: 'text-gray-300 hover:text-neon-green hover:bg-glow-green-50 cyber-border border-transparent hover:border-neon-green'}"
					>
						<span class="mr-2">{item.icon}</span>
						{item.label}
					</a>
				{/each}
			</div>
			
			<!-- User Actions -->
			<div class="flex items-center space-x-4">
				<button class="cyber-button text-xs">
					<span class="mr-2">⚡</span>
					New Repo
				</button>
				<div class="flex items-center space-x-2 text-sm">
					<span class="text-terminal-amber">●</span>
					<span class="text-gray-400">admin</span>
				</div>
			</div>
		</div>
		
		<!-- Mobile Navigation -->
		<div class="md:hidden pb-4">
			<div class="flex flex-wrap gap-2">
				{#each navItems as item}
					<a 
						href={item.href}
						class="px-3 py-2 rounded-sm transition-all duration-200 font-medium text-xs uppercase tracking-wider
							{currentPath === item.href 
								? 'bg-glow-green-50 text-neon-green cyber-border-glow' 
								: 'text-gray-300 hover:text-neon-green hover:bg-glow-green-50 cyber-border border-transparent hover:border-neon-green'}"
					>
						<span class="mr-1">{item.icon}</span>
						{item.label}
					</a>
				{/each}
			</div>
		</div>
	</div>
</nav>