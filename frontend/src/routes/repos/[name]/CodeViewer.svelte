<script lang="ts">
	let { file }: { file: string } = $props();
	
	// Mock file content - will be replaced with API calls
	const fileContents: Record<string, string> = {
		'package.json': `{
  "name": "awesome-project",
  "version": "1.0.0",
  "description": "A cyberpunk-themed web application",
  "type": "module",
  "scripts": {
    "dev": "vite dev",
    "build": "vite build",
    "preview": "vite preview"
  },
  "devDependencies": {
    "@sveltejs/kit": "^2.0.0",
    "@tailwindcss/vite": "^4.0.0",
    "svelte": "^5.0.0",
    "tailwindcss": "^4.0.0",
    "typescript": "^5.0.0",
    "vite": "^7.0.0"
  }
}`,
		'README.md': `# Awesome Project

A cyberpunk-themed web application with neon aesthetics and terminal-inspired interface design.

## Features

- 🌟 Cyberpunk UI with neon colors
- 🖥️ Terminal-inspired design
- ⚡ Built with SvelteKit and TypeScript
- 🎨 Styled with Tailwind CSS

## Getting Started

\`\`\`bash
# Install dependencies
npm install

# Start development server
npm run dev
\`\`\`

## License

MIT License`,
		'src/app.css': `@import 'tailwindcss';

/* Cyberpunk Theme Configuration */
:root {
  --color-cyber-black: #0a0a0a;
  --color-neon-green: #00ff41;
  --color-neon-cyan: #00ffff;
}

html, body {
  background-color: var(--color-cyber-black);
  color: var(--color-neon-green);
  font-family: 'JetBrains Mono', monospace;
}`,
		'src/routes/+page.svelte': `<script lang="ts">
  import { onMount } from 'svelte';
  
  let count = $state(0);
  
  function increment() {
    count++;
  }
</script>

<h1>Welcome to the Cyberpunk Future</h1>
<p>Counter: {count}</p>
<button onclick={increment}>Increment</button>`
	};
	
	let content = $derived(fileContents[file] || `// File: ${file}\n// Content loading...`);
	let language = $derived(getFileLanguage(file));
	let lineCount = $derived(content.split('\n').length);
	
	function getFileLanguage(filename: string): string {
		const ext = filename.split('.').pop()?.toLowerCase();
		switch (ext) {
			case 'js': return 'javascript';
			case 'ts': return 'typescript';
			case 'svelte': return 'svelte';
			case 'css': return 'css';
			case 'html': return 'html';
			case 'json': return 'json';
			case 'md': return 'markdown';
			default: return 'text';
		}
	}
	
	function copyToClipboard() {
		navigator.clipboard.writeText(content);
	}
	
	function downloadFile() {
		const blob = new Blob([content], { type: 'text/plain' });
		const url = URL.createObjectURL(blob);
		const a = document.createElement('a');
		a.href = url;
		a.download = file.split('/').pop() || 'file.txt';
		a.click();
		URL.revokeObjectURL(url);
	}
</script>

<div class="cyber-bg-panel rounded-sm overflow-hidden">
	<!-- File Header -->
	<div class="flex items-center justify-between p-4 border-b border-gray-700 cyber-bg-dark">
		<div class="flex items-center space-x-3">
			<span class="text-neon-yellow">📄</span>
			<span class="font-mono text-sm text-gray-300">{file}</span>
			<span class="px-2 py-1 bg-cyber-gray text-xs text-gray-400 rounded-sm font-mono uppercase">
				{language}
			</span>
		</div>
		
		<div class="flex items-center space-x-2">
			<span class="text-xs text-gray-500 font-mono">{lineCount} lines</span>
			
			<button onclick={copyToClipboard} class="cyber-button text-xs" title="Copy to clipboard">
				📋
			</button>
			
			<button onclick={downloadFile} class="cyber-button text-xs" title="Download file">
				💾
			</button>
		</div>
	</div>
	
	<!-- Code Content -->
	<div class="relative">
		<!-- Line Numbers -->
		<div class="absolute left-0 top-0 bottom-0 w-12 cyber-bg-darker border-r border-gray-700 select-none">
			{#each Array(lineCount) as _, i}
				<div class="px-2 py-1 text-xs text-gray-500 font-mono text-right leading-6">
					{i + 1}
				</div>
			{/each}
		</div>
		
		<!-- Code -->
		<div class="ml-12 overflow-x-auto">
			<pre class="p-4 text-sm font-mono leading-6 text-gray-300"><code>{content}</code></pre>
		</div>
	</div>
	
	<!-- File Stats -->
	<div class="flex items-center justify-between p-4 border-t border-gray-700 cyber-bg-dark text-xs text-gray-500">
		<div class="flex items-center space-x-4">
			<span>Size: {new Blob([content]).size} bytes</span>
			<span>Encoding: UTF-8</span>
		</div>
		
		<div class="flex items-center space-x-2">
			<span class="text-terminal-green">●</span>
			<span>Last modified: 2 hours ago</span>
		</div>
	</div>
</div>