// Git Station Frontend Constants and Enums

// ===== ENUMS =====

export enum IssueState {
	OPEN = 'open',
	CLOSED = 'closed'
}

export enum PullRequestState {
	OPEN = 'open',
	CLOSED = 'closed',
	MERGED = 'merged'
}

export enum RepositoryStatus {
	ACTIVE = 'active',
	ARCHIVED = 'archived'
}

export enum ProgrammingLanguage {
	TYPESCRIPT = 'TypeScript',
	JAVASCRIPT = 'JavaScript',
	PYTHON = 'Python',
	RUST = 'Rust',
	GO = 'Go',
	JAVA = 'Java',
	CPP = 'C++',
	CSHARP = 'C#',
	ZIG = 'Zig'
}

export enum RepositoryTabType {
	FILES = 'files',
	COMMITS = 'commits',
	BRANCHES = 'branches',
	ISSUES = 'issues',
	PULLS = 'pulls'
}

export enum FilterState {
	ALL = 'all',
	OPEN = 'open',
	CLOSED = 'closed',
	MERGED = 'merged'
}

export enum CommitType {
	FEAT = 'feat',
	FIX = 'fix',
	DOCS = 'docs',
	STYLE = 'style',
	REFACTOR = 'refactor',
	TEST = 'test',
	CHORE = 'chore'
}

// ===== STYLING CONSTANTS =====

export const COLORS = {
	// Cyberpunk theme colors
	NEON_GREEN: 'text-neon-green',
	NEON_CYAN: 'text-neon-cyan',
	NEON_PINK: 'text-neon-pink',
	NEON_PURPLE: 'text-neon-purple',
	TERMINAL_RED: 'text-terminal-red',
	TERMINAL_AMBER: 'text-terminal-amber',
	TERMINAL_GREEN: 'text-terminal-green',
	
	// Background colors
	BG_NEON_GREEN: 'bg-green-900/20',
	BG_NEON_CYAN: 'bg-cyan-900/20',
	BG_NEON_PINK: 'bg-pink-900/20',
	BG_NEON_PURPLE: 'bg-purple-900/20',
	BG_TERMINAL_RED: 'bg-red-900/20',
	BG_TERMINAL_AMBER: 'bg-yellow-900/20',
	
	// Border colors
	BORDER_NEON_GREEN: 'border-neon-green',
	BORDER_NEON_CYAN: 'border-neon-cyan',
	BORDER_NEON_PINK: 'border-neon-pink',
	BORDER_NEON_PURPLE: 'border-neon-purple',
	BORDER_TERMINAL_RED: 'border-terminal-red',
	BORDER_TERMINAL_AMBER: 'border-terminal-amber'
} as const;

export const LANGUAGE_COLORS: Record<ProgrammingLanguage, string> = {
	[ProgrammingLanguage.TYPESCRIPT]: 'text-blue-400',
	[ProgrammingLanguage.JAVASCRIPT]: 'text-yellow-400',
	[ProgrammingLanguage.PYTHON]: 'text-green-400',
	[ProgrammingLanguage.RUST]: 'text-orange-400',
	[ProgrammingLanguage.GO]: 'text-cyan-400',
	[ProgrammingLanguage.JAVA]: 'text-red-400',
	[ProgrammingLanguage.CPP]: 'text-pink-400',
	[ProgrammingLanguage.CSHARP]: 'text-purple-400',
	[ProgrammingLanguage.ZIG]: 'text-amber-400'
};

export const ISSUE_STATE_COLORS: Record<IssueState, string> = {
	[IssueState.OPEN]: `${COLORS.NEON_GREEN} ${COLORS.BG_NEON_GREEN} ${COLORS.BORDER_NEON_GREEN}`,
	[IssueState.CLOSED]: `${COLORS.NEON_PURPLE} ${COLORS.BG_NEON_PURPLE} ${COLORS.BORDER_NEON_PURPLE}`
};

export const PULL_REQUEST_STATE_COLORS: Record<PullRequestState, string> = {
	[PullRequestState.OPEN]: `${COLORS.NEON_GREEN} ${COLORS.BG_NEON_GREEN} ${COLORS.BORDER_NEON_GREEN}`,
	[PullRequestState.MERGED]: `${COLORS.NEON_PURPLE} ${COLORS.BG_NEON_PURPLE} ${COLORS.BORDER_NEON_PURPLE}`,
	[PullRequestState.CLOSED]: `${COLORS.TERMINAL_RED} ${COLORS.BG_TERMINAL_RED} ${COLORS.BORDER_TERMINAL_RED}`
};

export const PULL_REQUEST_ICONS: Record<PullRequestState, string> = {
	[PullRequestState.OPEN]: '⇄',
	[PullRequestState.MERGED]: '✓',
	[PullRequestState.CLOSED]: '✕'
};

export const REPOSITORY_STATUS_COLORS: Record<RepositoryStatus, string> = {
	[RepositoryStatus.ACTIVE]: COLORS.TERMINAL_GREEN,
	[RepositoryStatus.ARCHIVED]: COLORS.TERMINAL_AMBER
};

export const COMMIT_TYPE_COLORS: Record<CommitType, string> = {
	[CommitType.FEAT]: COLORS.NEON_GREEN,
	[CommitType.FIX]: COLORS.TERMINAL_RED,
	[CommitType.DOCS]: COLORS.NEON_CYAN,
	[CommitType.REFACTOR]: COLORS.NEON_PURPLE,
	[CommitType.TEST]: COLORS.TERMINAL_AMBER,
	[CommitType.STYLE]: COLORS.NEON_PINK,
	[CommitType.CHORE]: 'text-gray-300'
};

// ===== LABEL CONSTANTS =====

export const LABEL_COLORS: Record<string, string> = {
	'bug': `${COLORS.TERMINAL_RED} ${COLORS.BG_TERMINAL_RED} ${COLORS.BORDER_TERMINAL_RED}`,
	'enhancement': `${COLORS.NEON_GREEN} ${COLORS.BG_NEON_GREEN} ${COLORS.BORDER_NEON_GREEN}`,
	'security': `${COLORS.NEON_PURPLE} ${COLORS.BG_NEON_PURPLE} ${COLORS.BORDER_NEON_PURPLE}`,
	'frontend': `${COLORS.NEON_CYAN} ${COLORS.BG_NEON_CYAN} ${COLORS.BORDER_NEON_CYAN}`,
	'backend': `${COLORS.NEON_PINK} ${COLORS.BG_NEON_PINK} ${COLORS.BORDER_NEON_PINK}`,
	'api': `${COLORS.TERMINAL_AMBER} bg-yellow-900/20 ${COLORS.BORDER_TERMINAL_AMBER}`,
	'high-priority': `${COLORS.NEON_PINK} ${COLORS.BG_NEON_PINK} ${COLORS.BORDER_NEON_PINK}`,
	'good-first-issue': `${COLORS.NEON_GREEN} ${COLORS.BG_NEON_GREEN} ${COLORS.BORDER_NEON_GREEN}`,
	'resolved': 'text-gray-400 bg-gray-900/20 border-gray-400',
	'hotfix': `${COLORS.TERMINAL_AMBER} ${COLORS.BG_TERMINAL_AMBER} ${COLORS.BORDER_TERMINAL_AMBER}`,
	'refactor': 'text-gray-300 bg-gray-900/20 border-gray-300',
	'maintenance': 'text-gray-400 bg-gray-900/20 border-gray-400',
	'ui': `${COLORS.NEON_PINK} ${COLORS.BG_NEON_PINK} ${COLORS.BORDER_NEON_PINK}`
};

// ===== NAVIGATION CONSTANTS =====

export const NAV_ITEMS = [
	{ href: '/', label: 'Dashboard', icon: '⬢' },
	{ href: '/repos', label: 'Repositories', icon: '📁' },
	{ href: '/issues', label: 'Issues', icon: '⚠' },
	{ href: '/pulls', label: 'Pull Requests', icon: '⇄' }
] as const;

export const REPO_TABS = [
	{ id: RepositoryTabType.FILES, label: 'Files', icon: '📁', count: null },
	{ id: RepositoryTabType.COMMITS, label: 'Commits', icon: '🔄', count: '156' },
	{ id: RepositoryTabType.BRANCHES, label: 'Branches', icon: '🌿', count: null },
	{ id: RepositoryTabType.ISSUES, label: 'Issues', icon: '⚠', count: null },
	{ id: RepositoryTabType.PULLS, label: 'Pull Requests', icon: '⇄', count: null }
] as const;

// ===== FILE TYPE CONSTANTS =====

export const FILE_TYPE_ICONS: Record<string, string> = {
	'js': '⚡',
	'ts': '⚡',
	'svelte': '🔶',
	'css': '🎨',
	'html': '🌐',
	'json': '📋',
	'md': '📝',
	'gitignore': '🚫',
	'txt': '📄',
	'directory': '📁',
	'directory-open': '📂',
	'default': '📄'
};

export const FILE_CONTENT_TYPES: Record<string, string> = {
	'js': 'javascript',
	'ts': 'typescript',
	'svelte': 'svelte',
	'css': 'css',
	'html': 'html',
	'json': 'json',
	'md': 'markdown',
	'py': 'python',
	'rs': 'rust',
	'go': 'go',
	'java': 'java',
	'zig': 'zig',
	'default': 'text'
};

// ===== AUTH CONSTANTS =====

export const DEFAULT_CREDENTIALS = {
	USERNAME: 'admin',
	PASSWORD: 'password123'
} as const;

// ===== API CONSTANTS =====

export const API_ENDPOINTS = {
	LOGIN: '/api/login',
	REPOS: '/api/repos',
	REPO: (name: string) => `/api/repo/${name}`,
	BRANCHES: (name: string) => `/api/repo/${name}/branches`,
	COMMITS: (name: string, branch: string) => `/api/repo/${name}/commits/${branch}`,
	TREE: (name: string, branch: string, path: string) => `/api/repo/${name}/tree/${branch}/${path}`,
	BLOB: (name: string, branch: string, path: string) => `/api/repo/${name}/blob/${branch}/${path}`,
	ISSUES: (name: string) => `/api/repo/${name}/issues`,
	ISSUE: (name: string, id: number) => `/api/repo/${name}/issues/${id}`,
	PULLS: (name: string) => `/api/repo/${name}/pulls`,
	PULL: (name: string, id: number) => `/api/repo/${name}/pulls/${id}`,
	PULL_MERGE: (name: string, id: number) => `/api/repo/${name}/pulls/${id}/merge`,
	PULL_CLOSE: (name: string, id: number) => `/api/repo/${name}/pulls/${id}/close`,
	PULL_DELETE_BRANCH: (name: string, id: number) => `/api/repo/${name}/pulls/${id}/delete-branch`
} as const;

// ===== UTILITY FUNCTIONS =====

export function getLabelColor(label: string): string {
	return LABEL_COLORS[label] || 'text-gray-400 bg-gray-900/20 border-gray-400';
}

export function getLanguageColor(language: ProgrammingLanguage | string): string {
	if (Object.values(ProgrammingLanguage).includes(language as ProgrammingLanguage)) {
		return LANGUAGE_COLORS[language as ProgrammingLanguage];
	}
	return 'text-gray-400';
}

export function getCommitTypeColor(message: string): string {
	for (const [type, color] of Object.entries(COMMIT_TYPE_COLORS)) {
		if (message.toLowerCase().startsWith(type)) {
			return color;
		}
	}
	return 'text-gray-300';
}

export function getFileIcon(name: string, type: 'file' | 'directory', isOpen = false): string {
	if (type === 'directory') {
		return isOpen ? FILE_TYPE_ICONS['directory-open'] : FILE_TYPE_ICONS['directory'];
	}
	
	const ext = name.split('.').pop()?.toLowerCase();
	return FILE_TYPE_ICONS[ext || 'default'] || FILE_TYPE_ICONS['default'];
}

export function getFileLanguage(filename: string): string {
	const ext = filename.split('.').pop()?.toLowerCase();
	return FILE_CONTENT_TYPES[ext || 'default'] || FILE_CONTENT_TYPES['default'];
}