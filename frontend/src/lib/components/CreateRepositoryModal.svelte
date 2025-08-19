<script lang="ts">
	import { API_ENDPOINTS } from '$lib/constants';
	
	let { isOpen = $bindable(), onRepositoryCreated }: {
		isOpen: boolean;
		onRepositoryCreated?: (repoName: string) => void;
	} = $props();
	
	let repoName = $state('');
	let description = $state('');
	let isPrivate = $state(false);
	let isLoading = $state(false);
	let error = $state('');
	
	async function createRepository() {
		if (!repoName.trim()) {
			error = 'Repository name is required';
			return;
		}
		
		if (!/^[a-zA-Z0-9_-]+$/.test(repoName.trim())) {
			error = 'Repository name can only contain letters, numbers, hyphens, and underscores';
			return;
		}
		
		isLoading = true;
		error = '';
		
		try {
			const response = await fetch(API_ENDPOINTS.REPOS, {
				method: 'POST',
				headers: {
					'Content-Type': 'application/json',
				},
				credentials: 'include',
				body: JSON.stringify({
					name: repoName.trim(),
					description: description.trim() || undefined,
					private: isPrivate
				})
			});
			
			if (!response.ok) {
				const errorData = await response.json().catch(() => ({}));
				throw new Error(errorData.message || `HTTP ${response.status}: ${response.statusText}`);
			}
			
			// Success! Close modal and notify parent
			closeModal();
			onRepositoryCreated?.(repoName.trim());
			
		} catch (err) {
			error = err instanceof Error ? err.message : 'Failed to create repository';
		} finally {
			isLoading = false;
		}
	}
	
	function closeModal() {
		isOpen = false;
		// Reset form
		repoName = '';
		description = '';
		isPrivate = false;
		error = '';
	}
	
	function handleKeydown(event: KeyboardEvent) {
		if (event.key === 'Escape') {
			closeModal();
		} else if (event.key === 'Enter' && event.ctrlKey) {
			createRepository();
		}
	}
</script>

<svelte:window onkeydown={handleKeydown} />

{#if isOpen}
	<!-- Modal Backdrop -->
	<div 
		class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50" 
		onclick={closeModal}
		onkeydown={(e) => e.key === 'Escape' && closeModal()}
		role="dialog"
		aria-modal="true"
		aria-labelledby="modal-title"
		tabindex="-1"
	>
		<!-- Modal Content -->
		<div 
			class="cyber-bg-panel p-6 rounded-sm max-w-md w-full mx-4 border border-gray-700" 
			onclick={(e) => e.stopPropagation()}
		>
			<!-- Header -->
			<div class="flex items-center justify-between mb-6">
				<h2 id="modal-title" class="text-xl font-bold cyber-text-glow">
					<span class="text-neon-green">></span> Create Repository
				</h2>
				<button onclick={closeModal} class="text-gray-400 hover:text-neon-green transition-colors">
					<span class="text-xl">✕</span>
				</button>
			</div>
			
			<!-- Form -->
			<div class="space-y-4">
				<!-- Repository Name -->
				<div>
					<label for="repo-name" class="block text-sm font-medium text-gray-300 mb-2">
						Repository Name *
					</label>
					<input
						id="repo-name"
						type="text"
						bind:value={repoName}
						placeholder="my-awesome-project"
						class="cyber-input w-full"
						disabled={isLoading}
						autocomplete="off"
					/>
					<p class="text-xs text-gray-500 mt-1">
						Letters, numbers, hyphens, and underscores only
					</p>
				</div>
				
				<!-- Description -->
				<div>
					<label for="repo-description" class="block text-sm font-medium text-gray-300 mb-2">
						Description
					</label>
					<textarea
						id="repo-description"
						bind:value={description}
						placeholder="A brief description of your repository"
						rows="3"
						class="cyber-input w-full resize-none"
						disabled={isLoading}
					></textarea>
				</div>
				
				<!-- Private Repository -->
				<div class="flex items-center space-x-2">
					<input
						id="repo-private"
						type="checkbox"
						bind:checked={isPrivate}
						class="w-4 h-4 text-neon-green border-gray-600 rounded focus:ring-neon-green bg-cyber-dark"
						disabled={isLoading}
					/>
					<label for="repo-private" class="text-sm text-gray-300">
						Private repository
					</label>
				</div>
				
				<!-- Error Message -->
				{#if error}
					<div class="p-3 bg-red-900/20 border border-terminal-red rounded-sm">
						<p class="text-terminal-red text-sm">{error}</p>
					</div>
				{/if}
			</div>
			
			<!-- Actions -->
			<div class="flex items-center justify-end space-x-3 mt-6 pt-4 border-t border-gray-700">
				<button
					onclick={closeModal}
					class="px-4 py-2 text-gray-400 hover:text-gray-300 transition-colors"
					disabled={isLoading}
				>
					Cancel
				</button>
				<button
					onclick={createRepository}
					class="cyber-button"
					disabled={isLoading || !repoName.trim()}
				>
					{#if isLoading}
						<span class="mr-2">⏳</span>
						Creating...
					{:else}
						<span class="mr-2">+</span>
						Create Repository
					{/if}
				</button>
			</div>
			
			<!-- Keyboard Shortcuts -->
			<div class="mt-4 pt-4 border-t border-gray-700">
				<p class="text-xs text-gray-500">
					Press <kbd class="px-1 py-0.5 bg-gray-800 rounded text-xs">Esc</kbd> to cancel or 
					<kbd class="px-1 py-0.5 bg-gray-800 rounded text-xs">Ctrl+Enter</kbd> to create
				</p>
			</div>
		</div>
	</div>
{/if}

<style>
	kbd {
		font-family: ui-monospace, 'SF Mono', 'Monaco', 'Inconsolata', 'Roboto Mono', monospace;
	}
</style>