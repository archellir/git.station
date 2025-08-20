import { writable } from 'svelte/store';
import { browser } from '$app/environment';
import { goto } from '$app/navigation';

interface User {
	username: string;
}

interface AuthState {
	isAuthenticated: boolean;
	user: User | null;
	isLoading: boolean;
}

// Create the auth store
function createAuthStore() {
	const { subscribe, set, update } = writable<AuthState>({
		isAuthenticated: false,
		user: null,
		isLoading: true
	});

	return {
		subscribe,
		
		// Initialize auth state from localStorage
		init() {
			if (browser) {
				const authStored = localStorage.getItem('auth');
				const userStored = localStorage.getItem('user');
				
				if (authStored === 'true' && userStored) {
					try {
						const user = JSON.parse(userStored);
						set({
							isAuthenticated: true,
							user,
							isLoading: false
						});
					} catch {
						// Invalid stored data, clear it
						localStorage.removeItem('auth');
						localStorage.removeItem('user');
						set({
							isAuthenticated: false,
							user: null,
							isLoading: false
						});
					}
				} else {
					set({
						isAuthenticated: false,
						user: null,
						isLoading: false
					});
				}
			}
		},

		// Login function
		async login(username: string, password: string): Promise<{ success: boolean; error?: string }> {
			update(state => ({ ...state, isLoading: true }));

			try {
				// Make actual API call to backend
				const response = await fetch('/api/login', {
					method: 'POST',
					headers: {
						'Content-Type': 'application/json',
					},
					credentials: 'include', // Important: send/receive cookies
					body: JSON.stringify({ username, password })
				});

				if (response.ok) {
					const user = { username };
					
					if (browser) {
						localStorage.setItem('auth', 'true');
						localStorage.setItem('user', JSON.stringify(user));
					}
					
					set({
						isAuthenticated: true,
						user,
						isLoading: false
					});
					
					return { success: true };
				} else {
					set({
						isAuthenticated: false,
						user: null,
						isLoading: false
					});
					
					const errorData = await response.json().catch(() => ({ error: 'Authentication failed' }));
					return { success: false, error: errorData.error || 'Invalid credentials. Access denied.' };
				}
			} catch (error) {
				set({
					isAuthenticated: false,
					user: null,
					isLoading: false
				});
				return { success: false, error: 'Connection error. Unable to authenticate.' };
			}
		},

		// Logout function
		async logout() {
			try {
				// Call backend logout endpoint
				await fetch('/api/logout', {
					method: 'POST',
					credentials: 'include'
				});
			} catch (error) {
				console.warn('Logout API call failed:', error);
			}
			
			if (browser) {
				localStorage.removeItem('auth');
				localStorage.removeItem('user');
			}
			
			set({
				isAuthenticated: false,
				user: null,
				isLoading: false
			});
			
			goto('/login');
		},

		// Check if user is authenticated
		requireAuth() {
			const currentState = this.getCurrent();
			if (!currentState.isAuthenticated && !currentState.isLoading) {
				goto('/login');
				return false;
			}
			return true;
		},

		// Get current state (helper function)
		getCurrent(): AuthState {
			let currentState: AuthState = {
				isAuthenticated: false,
				user: null,
				isLoading: true
			};
			
			subscribe(state => {
				currentState = state;
			})();
			
			return currentState;
		}
	};
}

export const auth = createAuthStore();