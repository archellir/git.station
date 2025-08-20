<script lang="ts">
	import '../app.css';
	import favicon from '$lib/assets/favicon.svg';
	import Navigation from './Navigation.svelte';
	import { auth } from '$lib/stores/auth';
	import { onMount } from 'svelte';
	import { page } from '$app/stores';
	import { goto } from '$app/navigation';

	let { children } = $props();

	// Initialize authentication on mount
	onMount(() => {
		auth.init();
	});

	// Reactive check for authentication
	$effect(() => {
		// Allow access to login page without authentication
		if ($page.route.id === '/login') {
			return;
		}

		// Check if user is authenticated for protected routes
		if (!$auth.isLoading && !$auth.isAuthenticated) {
			goto('/login');
		}
	});
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
	{#if $auth.isAuthenticated || $page.route.id === '/login'}
		{#if $auth.isAuthenticated && $page.route.id !== '/login'}
			<Navigation />
		{/if}
		<main class="{$auth.isAuthenticated && $page.route.id !== '/login' ? 'container mx-auto px-4 py-8' : ''}">
			{@render children?.()}
		</main>
	{:else if $auth.isLoading}
		<!-- Loading state -->
		<div class="min-h-screen flex items-center justify-center">
			<div class="text-center">
				<div class="animate-spin text-4xl mb-4">⏳</div>
				<div class="text-neon-green font-mono">Initializing system...</div>
			</div>
		</div>
	{/if}
</div>
