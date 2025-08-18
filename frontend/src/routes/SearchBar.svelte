<script lang="ts">
	let { value = $bindable(''), placeholder = 'Search...' }: { 
		value: string; 
		placeholder?: string; 
	} = $props();
	
	let focused = $state(false);
</script>

<div class="relative">
	<div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
		<span class="text-gray-400">🔍</span>
	</div>
	
	<input
		type="text"
		bind:value
		{placeholder}
		onfocus={() => focused = true}
		onblur={() => focused = false}
		class="w-full pl-10 pr-4 cyber-input
			{focused ? 'cyber-border-glow' : 'cyber-border'}
			placeholder:text-gray-500 placeholder:font-mono placeholder:text-sm"
	/>
	
	{#if value}
		<button
			onclick={() => value = ''}
			class="absolute inset-y-0 right-0 pr-3 flex items-center text-gray-400 hover:text-neon-green transition-colors"
		>
			<span class="text-sm">✕</span>
		</button>
	{/if}
	
	{#if focused}
		<div class="absolute right-2 top-1/2 transform -translate-y-1/2">
			<span class="text-xs text-gray-500 font-mono">ESC</span>
		</div>
	{/if}
</div>