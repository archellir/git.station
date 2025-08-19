<script lang="ts">
	type ButtonVariant = 'primary' | 'secondary' | 'danger' | 'text';
	type ButtonSize = 'xs' | 'sm' | 'md' | 'lg';

	let {
		variant = 'primary',
		size = 'md',
		disabled = false,
		loading = false,
		icon = '',
		onclick,
		type = 'button',
		class: className = '',
		children,
		...restProps
	}: {
		variant?: ButtonVariant;
		size?: ButtonSize;
		disabled?: boolean;
		loading?: boolean;
		icon?: string;
		onclick?: (event: MouseEvent) => void;
		type?: 'button' | 'submit' | 'reset';
		class?: string;
		children?: any;
		[key: string]: any;
	} = $props();

	// Variant classes
	const variantClasses = {
		primary: 'cyber-button',
		secondary: 'cyber-button-secondary',
		danger: 'bg-transparent border border-terminal-red text-terminal-red hover:bg-red-900/20 hover:border-terminal-red hover:shadow-[0_0_8px_rgba(255,0,64,0.2)]',
		text: 'bg-transparent border-0 text-gray-400 hover:text-neon-green transition-colors underline p-0'
	};

	// Size classes
	const sizeClasses = {
		xs: 'text-xs px-1 py-1',
		sm: 'text-xs px-3 py-2',
		md: 'text-sm px-4 py-2',
		lg: 'text-base px-6 py-3'
	};

	// Combine all classes
	const buttonClasses = [
		variantClasses[variant],
		sizeClasses[size],
		disabled || loading ? 'opacity-50 cursor-not-allowed' : '',
		className
	].filter(Boolean).join(' ');

	function handleClick(event: MouseEvent) {
		if (disabled || loading) {
			event.preventDefault();
			return;
		}
		onclick?.(event);
	}
</script>

<button
	{type}
	class={buttonClasses}
	onclick={handleClick}
	disabled={disabled || loading}
	{...restProps}
>
	{#if loading}
		<span class="mr-2">⏳</span>
	{:else if icon}
		<span class="mr-2">{icon}</span>
	{/if}
	
	<slot />
</button>

<style>
	/* Additional styles can be added here if needed */
</style>