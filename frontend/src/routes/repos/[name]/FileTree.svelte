<script lang="ts">
	import type { FileTreeItem } from '$lib/types';
	import { getFileIcon } from '$lib/constants';
	
	let { selectedFile = $bindable(), branch }: { 
		selectedFile: string | null; 
		branch: string;
	} = $props();
	
	// Mock file tree data - will be replaced with API calls
	let fileTree = [
		{
			name: 'src',
			type: 'directory',
			children: [
				{ name: 'components', type: 'directory', children: [
					{ name: 'Button.svelte', type: 'file', size: '1.2 KB' },
					{ name: 'Navigation.svelte', type: 'file', size: '3.4 KB' },
					{ name: 'Modal.svelte', type: 'file', size: '2.1 KB' }
				]},
				{ name: 'routes', type: 'directory', children: [
					{ name: '+layout.svelte', type: 'file', size: '856 B' },
					{ name: '+page.svelte', type: 'file', size: '4.2 KB' }
				]},
				{ name: 'lib', type: 'directory', children: [
					{ name: 'utils.ts', type: 'file', size: '2.8 KB' },
					{ name: 'api.ts', type: 'file', size: '5.1 KB' }
				]},
				{ name: 'app.css', type: 'file', size: '12.3 KB' },
				{ name: 'app.html', type: 'file', size: '485 B' }
			]
		},
		{ name: 'package.json', type: 'file', size: '1.1 KB' },
		{ name: 'tsconfig.json', type: 'file', size: '456 B' },
		{ name: 'vite.config.ts', type: 'file', size: '732 B' },
		{ name: 'README.md', type: 'file', size: '2.4 KB' },
		{ name: '.gitignore', type: 'file', size: '234 B' }
	];
	
	let expandedDirs = $state(new Set(['src', 'src/components', 'src/routes']));
	
	function toggleDirectory(path: string) {
		if (expandedDirs.has(path)) {
			expandedDirs.delete(path);
		} else {
			expandedDirs.add(path);
		}
		expandedDirs = new Set(expandedDirs);
	}
	
	function getFileIconWithState(name: string, type: 'file' | 'directory') {
		if (type === 'directory') {
			return getFileIcon(name, type, expandedDirs.has(name));
		}
		return getFileIcon(name, type);
	}
	
	function renderFileTree(items: any[], parentPath = '') {
		return items.map(item => {
			const currentPath = parentPath ? `${parentPath}/${item.name}` : item.name;
			return { ...item, path: currentPath };
		});
	}
</script>

<div class="space-y-1">
	<!-- Branch indicator -->
	<div class="flex items-center space-x-2 mb-4 p-2 cyber-bg-dark rounded-sm border border-gray-700">
		<span class="text-neon-green">🌿</span>
		<span class="font-mono text-sm text-gray-300">{branch}</span>
	</div>
	
	{#each renderFileTree(fileTree) as item}
		{@render fileItem(item, 0)}
	{/each}
</div>

{#snippet fileItem(item: any, depth: number)}
	<div style="margin-left: {depth * 16}px">
		{#if item.type === 'directory'}
			<button
				onclick={() => toggleDirectory(item.path)}
				class="flex items-center space-x-2 w-full p-2 text-left hover:bg-glow-green-50 rounded-sm transition-colors group"
			>
				<span class="text-neon-cyan group-hover:text-neon-green transition-colors">
					{getFileIconWithState(item.path, item.type)}
				</span>
				<span class="text-gray-300 group-hover:text-neon-green transition-colors font-mono text-sm">
					{item.name}
				</span>
			</button>
			
			{#if expandedDirs.has(item.path) && item.children}
				{#each renderFileTree(item.children, item.path) as child}
					{@render fileItem(child, depth + 1)}
				{/each}
			{/if}
		{:else}
			<button
				onclick={() => selectedFile = item.path}
				class="flex items-center justify-between w-full p-2 text-left rounded-sm transition-colors group
					{selectedFile === item.path 
						? 'bg-glow-green-100 border border-neon-green' 
						: 'hover:bg-glow-green-50'}"
			>
				<div class="flex items-center space-x-2 min-w-0 flex-1">
					<span class="text-neon-yellow group-hover:text-neon-green transition-colors">
						{getFileIconWithState(item.name, item.type)}
					</span>
					<span class="text-gray-300 group-hover:text-neon-green transition-colors font-mono text-sm truncate">
						{item.name}
					</span>
				</div>
				
				{#if item.size}
					<span class="text-xs text-gray-500 font-mono ml-2">{item.size}</span>
				{/if}
			</button>
		{/if}
	</div>
{/snippet}