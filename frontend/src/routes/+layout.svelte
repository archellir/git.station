<script lang="ts">
	import '../app.css';
	import favicon from '$lib/assets/favicon.svg';
	import Navigation from './Navigation.svelte';

	let { children } = $props();
</script>

<svelte:head>
	<title>Git Station</title>
	<meta name="description" content="Cyberpunk Git Hosting Service" />
	<link rel="icon" href={favicon} />
	<link rel="preconnect" href="https://fonts.googleapis.com" />
	<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
	<link href="https://fonts.googleapis.com/css2?family=JetBrains+Mono:ital,wght@0,400;0,500;0,700;1,400&display=swap" rel="stylesheet" />
</svelte:head>

<div class="min-h-screen cyber-bg-dark">
	<Navigation />
	<main class="container mx-auto px-4 py-8">
		{@render children?.()}
	</main>
</div>
