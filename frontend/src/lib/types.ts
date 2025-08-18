// Git Station Frontend Types

import type { 
	IssueState, 
	PullRequestState, 
	RepositoryStatus, 
	ProgrammingLanguage, 
	RepositoryTabType 
} from './constants';

// ===== CORE TYPES =====

export interface Repository {
	name: string;
	description: string;
	language: ProgrammingLanguage;
	stars: number;
	forks: number;
	lastCommit: string;
	status: RepositoryStatus;
}

export interface RepositoryDetails extends Repository {
	issues: number;
	pullRequests: number;
	branches: string[];
	size: string;
	license: string;
}

export interface Issue {
	id: number;
	title: string;
	body: string;
	state: IssueState;
	author: string;
	assignee?: string;
	labels: string[];
	createdAt: string;
	updatedAt: string;
	comments: number;
	repository: string;
}

export interface PullRequest {
	id: number;
	title: string;
	body: string;
	state: PullRequestState;
	author: string;
	reviewers: string[];
	sourceBranch: string;
	targetBranch: string;
	repository: string;
	createdAt: string;
	updatedAt: string;
	comments: number;
	commits: number;
	additions: number;
	deletions: number;
	filesChanged: number;
	labels: string[];
}

export interface Commit {
	hash: string;
	fullHash: string;
	message: string;
	author: string;
	timestamp: string;
	date: string;
	additions: number;
	deletions: number;
	files: number;
}

export interface FileTreeItem {
	name: string;
	type: 'file' | 'directory';
	size?: string;
	path?: string;
	children?: FileTreeItem[];
}

export interface NavigationItem {
	href: string;
	label: string;
	icon: string;
}

export interface RepositoryTab {
	id: RepositoryTabType;
	label: string;
	icon: string;
	count: string | null;
}

// ===== FILTER TYPES =====

export type FilterState = 'all' | IssueState | PullRequestState;

export interface FilterOptions {
	searchQuery: string;
	selectedState: FilterState;
	selectedRepository: string;
	selectedLanguage: string;
	selectedAuthor?: string;
	selectedLabel?: string;
}

// ===== COMPONENT PROPS TYPES =====

export interface RepositoryCardProps {
	repo: Repository;
}

export interface SearchBarProps {
	value: string;
	placeholder?: string;
}

export interface FileTreeProps {
	selectedFile: string | null;
	branch: string;
}

export interface CodeViewerProps {
	file: string;
}

export interface CommitHistoryProps {
	branch: string;
}

// ===== API RESPONSE TYPES =====

export interface ApiResponse<T> {
	success: boolean;
	data?: T;
	error?: string;
}

export interface LoginRequest {
	username: string;
	password: string;
}

export interface LoginResponse {
	token: string;
	user: {
		username: string;
	};
}

export interface CreateRepositoryRequest {
	name: string;
	description?: string;
	private?: boolean;
}

export interface CreateIssueRequest {
	title: string;
	body: string;
	labels?: string[];
	assignee?: string;
}

export interface UpdateIssueRequest {
	title?: string;
	body?: string;
	state?: IssueState;
	labels?: string[];
	assignee?: string;
}

export interface CreatePullRequestRequest {
	title: string;
	body: string;
	sourceBranch: string;
	targetBranch: string;
}

export interface UpdatePullRequestRequest {
	title?: string;
	body?: string;
	state?: PullRequestState;
}

// ===== UTILITY TYPES =====

export type SortOrder = 'asc' | 'desc';

export type SortBy = 'name' | 'stars' | 'language' | 'updated' | 'created';

export interface SortOptions {
	sortBy: SortBy;
	sortOrder: SortOrder;
}

// ===== STATE MANAGEMENT TYPES =====

export interface AuthState {
	isAuthenticated: boolean;
	user: {
		username: string;
	} | null;
	token: string | null;
}

export interface AppState {
	auth: AuthState;
	repositories: Repository[];
	currentRepository: RepositoryDetails | null;
	loading: boolean;
	error: string | null;
}

// ===== FORM TYPES =====

export interface LoginFormData {
	username: string;
	password: string;
}

export interface CreateRepositoryFormData {
	name: string;
	description: string;
	private: boolean;
}

export interface IssueFormData {
	title: string;
	body: string;
	labels: string[];
	assignee: string;
}

export interface PullRequestFormData {
	title: string;
	body: string;
	sourceBranch: string;
	targetBranch: string;
}

// ===== EVENT TYPES =====

export interface RepositoryEvent {
	type: 'create' | 'update' | 'delete';
	repository: Repository;
}

export interface IssueEvent {
	type: 'create' | 'update' | 'close' | 'reopen';
	issue: Issue;
}

export interface PullRequestEvent {
	type: 'create' | 'update' | 'merge' | 'close';
	pullRequest: PullRequest;
}