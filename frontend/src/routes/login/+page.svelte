<script lang="ts">
	import { goto } from '$app/navigation';
	
	let username = $state('');
	let password = $state('');
	let isLoading = $state(false);
	let errorMessage = $state('');
	
	async function handleLogin(event: SubmitEvent) {
		event.preventDefault();
		
		if (!username || !password) {
			errorMessage = 'Username and password are required';
			return;
		}
		
		isLoading = true;
		errorMessage = '';
		
		try {
			// Mock authentication - will be replaced with API call
			if (username === 'admin' && password === 'password123') {
				// Store auth state (mock)
				localStorage.setItem('auth', 'true');
				localStorage.setItem('user', JSON.stringify({ username: 'admin' }));
				
				// Redirect to dashboard
				await goto('/');
			} else {
				errorMessage = 'Invalid credentials. Access denied.';
			}
		} catch (error) {
			errorMessage = 'Connection error. Unable to authenticate.';
		} finally {
			isLoading = false;
		}
	}
	
	function clearError() {
		errorMessage = '';
	}
</script>

<svelte:head>
	<title>Access Terminal - Git Station</title>
</svelte:head>

<div class="min-h-screen flex items-center justify-center cyber-bg-dark p-4">
	<div class="w-full max-w-md">
		<!-- Terminal Header -->
		<div class="cyber-bg-panel rounded-sm mb-6">
			<div class="cyber-bg-darker p-4 border-b border-gray-700 rounded-t-sm">
				<div class="flex items-center space-x-2">
					<div class="flex space-x-1">
						<div class="w-3 h-3 rounded-full bg-terminal-red"></div>
						<div class="w-3 h-3 rounded-full bg-terminal-amber"></div>
						<div class="w-3 h-3 rounded-full bg-neon-green"></div>
					</div>
					<span class="text-xs text-gray-400 font-mono">git-station://auth/terminal</span>
				</div>
			</div>
			
			<!-- Login Terminal -->
			<div class="p-6">
				<!-- ASCII Art Header -->
				<div class="text-neon-green font-mono text-xs mb-6 text-center">
					<pre class="cyber-text-glow">{`
  ██████  ██ ████████     ███████ ████████  █████  ████████ ██  ██████  ███    ██ 
 ██       ██    ██        ██         ██    ██   ██    ██    ██ ██    ██ ████   ██ 
 ██   ███ ██    ██        ███████    ██    ███████    ██    ██ ██    ██ ██ ██  ██ 
 ██    ██ ██    ██             ██    ██    ██   ██    ██    ██ ██    ██ ██  ██ ██ 
  ██████  ██    ██        ███████    ██    ██   ██    ██    ██  ██████  ██   ████ 
					`}</pre>
				</div>
				
				<!-- System Status -->
				<div class="mb-6 text-sm font-mono">
					<div class="flex items-center justify-between mb-2">
						<span class="text-gray-400">SYSTEM STATUS:</span>
						<span class="text-neon-green">ONLINE</span>
					</div>
					<div class="flex items-center justify-between mb-2">
						<span class="text-gray-400">SECURITY LEVEL:</span>
						<span class="text-terminal-amber">HIGH</span>
					</div>
					<div class="flex items-center justify-between mb-4">
						<span class="text-gray-400">ACCESS CONTROL:</span>
						<span class="text-terminal-red">LOCKED</span>
					</div>
				</div>
				
				<!-- Terminal Prompt -->
				<div class="mb-4">
					<div class="text-neon-green font-mono text-sm mb-2">
						<span class="terminal-cursor">root@git-station:~$</span> authenticate
					</div>
					<div class="text-gray-400 text-sm font-mono mb-4">
						Initializing secure authentication protocol...
					</div>
				</div>
				
				<!-- Login Form -->
				<form onsubmit={handleLogin} class="space-y-4">
					<!-- Error Message -->
					{#if errorMessage}
						<div class="cyber-bg-dark p-3 rounded-sm border border-terminal-red">
							<div class="flex items-center space-x-2">
								<span class="text-terminal-red text-sm">⚠</span>
								<span class="text-terminal-red text-sm font-mono">ERROR:</span>
								<span class="text-gray-300 text-sm">{errorMessage}</span>
							</div>
						</div>
					{/if}
					
					<!-- Username Input -->
					<div class="space-y-2">
						<label for="username" class="block text-neon-green text-sm font-mono">
							<span class="terminal-cursor">USERNAME:</span>
						</label>
						<input
							id="username"
							type="text"
							bind:value={username}
							oninput={clearError}
							placeholder="Enter username"
							disabled={isLoading}
							class="w-full cyber-input font-mono placeholder:text-gray-600"
							autocomplete="username"
							required
						/>
					</div>
					
					<!-- Password Input -->
					<div class="space-y-2">
						<label for="password" class="block text-neon-green text-sm font-mono">
							<span class="terminal-cursor">PASSWORD:</span>
						</label>
						<input
							id="password"
							type="password"
							bind:value={password}
							oninput={clearError}
							placeholder="Enter password"
							disabled={isLoading}
							class="w-full cyber-input font-mono placeholder:text-gray-600"
							autocomplete="current-password"
							required
						/>
					</div>
					
					<!-- Submit Button -->
					<button
						type="submit"
						disabled={isLoading || !username || !password}
						class="w-full cyber-button py-3 font-mono text-sm disabled:opacity-50 disabled:cursor-not-allowed"
					>
						{#if isLoading}
							<span class="flex items-center justify-center space-x-2">
								<span class="animate-spin">⏳</span>
								<span>AUTHENTICATING...</span>
							</span>
						{:else}
							<span class="flex items-center justify-center space-x-2">
								<span>🔓</span>
								<span>GRANT ACCESS</span>
							</span>
						{/if}
					</button>
				</form>
				
				<!-- System Info -->
				<div class="mt-6 pt-4 border-t border-gray-700 text-xs text-gray-500 font-mono text-center">
					<div class="space-y-1">
						<div>Git Station v1.0.0 - Secure Access Terminal</div>
						<div>Unauthorized access is strictly prohibited</div>
						<div class="text-terminal-amber">All activities are monitored and logged</div>
					</div>
				</div>
			</div>
		</div>
		
		<!-- Demo Credentials -->
		<div class="cyber-bg-panel p-4 rounded-sm text-center">
			<div class="text-xs text-gray-400 font-mono mb-2">DEMO CREDENTIALS:</div>
			<div class="text-xs text-gray-300 font-mono">
				<div>Username: <span class="text-neon-green">admin</span></div>
				<div>Password: <span class="text-neon-green">password123</span></div>
			</div>
		</div>
	</div>
</div>