`
``` markdown
- # Zero-Sum Envelope Budget App: Architectural Outline

## App Overview
This is a native iOS budgeting application built with SwiftUI, SwiftData, and CloudKit. It relies on a manual, zero-sum "envelope" budgeting philosophy. Users create overarching Accounts (e.g., Chase Checking) and populate them with Envelopes (e.g., Groceries, Gas). Every dollar earned via income must be allocated to an envelope, and expenses are deducted from these envelopes.

Key features include:
- **Smart Overdrafts:** Prompts and badges to resolve negative envelope balances.
- **Automation:** Background execution of recurring subscriptions and zero-sum paycheck splitting.
- **Cloud Collaboration:** Real-time syncing and sharing between household members using native Apple IDs via CloudKit (no third-party logins required).
- **Modular History:** A visually rich history dashboard featuring native charts and collapsible chronological lists.

## MVVM File Structure
To keep the codebase clean and maintainable, the app will use the Model-View-ViewModel (MVVM) architecture combined with Apple's SwiftData.

### 1. App Entry & Configuration
- **BudgetApp.swift**: The main entry point of the application. It sets up the SwiftData model container, configures CloudKit synchronization, and initializes the root MainTabView.

### 2. Models (SwiftData / Backend)
*These files define the data structures and how they are stored in the database. Using SwiftData's @Model macro, these will automatically sync via CloudKit.*

- **Account.swift**
  - **Properties:** id (UUID), name (String, e.g., "Capital One").
  - **Relationships:** @Relationship to an array of Envelope objects. If an account is deleted, its envelopes cascade and delete as well.
  - **Functionality:** Acts as the top-level container. Its total balance isn't stored as a raw number; instead, it is a computed property that sums the current balances of all its child envelopes.

- **Envelope.swift**
  - **Properties:** id (UUID), name (String), targetAmount (Optional Double, for sinking funds/goals), targetDate (Optional Date, for deadlines like vacations).
  - **Relationships:** Belongs to one Account. Has a one-to-many relationship with Transaction records.
  - **Functionality:** Tracks a specific budget category. Calculates its currentBalance by summing its related transactions. Contains a computed boolean isOverdrafted that triggers UI warnings when the balance drops below zero.

- **Transaction.swift**
  - **Properties:** id (UUID), amount (Double), date (Date), type (Enum: Income, Expense, Transfer), notes (String), tags (Array of Strings), userDisplayName (String, stamps who made the transaction).
  - **Relationships:** Belongs to an Envelope. (For transfers, it might hold a reference to a destinationEnvelope).
  - **Functionality:** The core movement of money. The userDisplayName is crucial here, as it automatically tracks which household member made the purchase without needing a login system.

- **RecurringItem.swift**
  - **Properties:** id (UUID), title (String), type (Enum: Paycheck, Subscription), nextExecutionDate (Date), frequency (Enum: Weekly, Bi-weekly, Monthly).
  - **Allocation Data:** totalAmount (Double). A splits dictionary mapping Envelope ID to a specific Fixed Dollar Amount.
  - **Functionality:** Stores the blueprint for automated background tasks. For a subscription, the split is simply 100% of the cost to one envelope. For a paycheck, this model enforces the "Zero-Sum" rule by ensuring the sum of the splits dictionary exactly equals the totalAmount before it can be saved.

### 3. ViewModels (Business Logic & State)
*These files handle the math, logic, and data preparation, keeping the UI (Views) clean and focused only on displaying information. They act as the bridge between the SwiftData Context and the SwiftUI Views.*

- **HomeViewModel.swift**
  - **Published State (Outputs to View):** Total Net Worth (Double), array of currently overdrawn Envelope objects.
  - **Core Functions:**
    - calculateTotalNetWorth(): Iterates through all accounts to sum their computed balances.
    - checkOverdrafts(): Scans the SwiftData context for any envelopes with a balance below zero.
    - resolveOverdraft(from sourceEnvelope: to overdrawnEnvelope: amount:): Executes the math and creates the necessary "Transfer" transactions to pull the overdrawn envelope back to zero.
    - addTransaction(amount: type: envelope: ...): Handles manual entry of a new income or expense, ensuring data validation and attaching the current user's display name before saving.

- **HistoryViewModel.swift**
  - **Published State (Outputs to View):** Grouped transactions (a structured dictionary mapping Month/Year -> Day -> [Transaction]), and aggregated chart data.
  - **Core Functions:**
    - fetchAndFilterTransactions(envelopeFilter: userFilter: dateRange:): Pulls data based on the user's current selections (e.g., viewing the whole budget vs. a specific envelope).
    - groupTransactionsForUI(): Takes a flat array of transactions and organizes them into the nested, chronological structure required by the UI's DisclosureGroup and Section views.
    - generatePieChartData(): Aggregates spending totals by category/envelope to feed directly into Apple's native Charts framework.

- **AutomationViewModel.swift**
  - **Published State (Outputs to View):** The current paycheck/subscription being drafted, unallocatedAmount (Double), and an isValidToSave boolean.
  - **Core Functions:**
    - calculateUnallocatedFunds(): Continuously subtracts the user's current fixed-dollar envelope splits from the total expected income to provide real-time UI feedback.
    - validateZeroSum(): A strict check ensuring unallocatedAmount exactly equals zero. Toggles the isValidToSave state, which enables/disables the save button in the UI.
    - quickSweep(to targetEnvelope:): Takes the exact remaining unallocatedAmount and automatically applies it to a selected envelope's split.

- **SettingsViewModel.swift**
  - **Published State (Outputs to View):** Current Display Name, Cloud Share status (Active/Inactive).
  - **Core Functions:**
    - saveDisplayName(name:): Persists the user's name locally using UserDefaults or AppStorage to be used for transaction metadata.
    - createAccount(), updateAccount(), deleteAccount(): Standard CRUD operations for managing the top-level bank accounts.
    - createEnvelope(for account:): Handles the setup of new envelopes within a specific parent account, including optional target dates and amounts.
    - initiateShare(): Triggers the native Apple UICloudSharingController to invite household members.

### 4. Views (SwiftUI UI Components)
*These files define the actual screens and visual elements the user interacts with, leaning heavily on native Apple UI paradigms.*

- **MainTabView.swift**
  - **Layout:** A native SwiftUI TabView containing four tabs: Home, History, Automation, and Settings.
  - **Functionality:** Serves as the root container, keeping the user anchored as they navigate the app.

- **HomeView.swift**
  - **Layout:** Wrapped in a NavigationStack. The .navigationTitle() dynamically displays the total net worth (e.g., "All Accounts: $17,322.30"). Uses a grouped List or LazyVGrid for large buttons representing each Account.
  - **Functionality:** Features a prominent persistent banner or button at the top if there are unresolved overdrafts. Tapping an account pushes the AccountDetailView.

- **AccountDetailView.swift**
  - **Layout:** A dynamic .navigationTitle showing the specific account name and its total balance (e.g., "Chase Bank Total: $15,205.12"). Uses a List to display rows for each Envelope belonging to that account.
  - **Functionality:** Includes a prominent + button in the toolbar to quickly add new manual transactions directly to envelopes within this account. Tapping an envelope row pushes the EnvelopeDetailView.

- **EnvelopeDetailView.swift**
  - **Layout:** Displays a large, bold header showing the envelope's remaining balance. Below that, it embeds the reusable TransactionListView.
  - **Functionality:** Shows a scoped view of the budget. By passing this specific envelope into the TransactionListView, it filters the history to only show relevant transactions while preserving the native back-navigation to the account overview.

- **HistoryView.swift**
  - **Layout:** A VStack containing two main sections. Top: A native SwiftUI Chart (using SectorMark for a pie/donut chart). Bottom: Embeds the reusable TransactionListView set to show all transactions.
  - **Functionality:** Includes a native Picker component above the chart allowing the user to filter data by Household Member (e.g., "All", "Noah", "Ashleigh").

- **TransactionListView.swift**
  - **Layout:** A reusable view utilizing a highly structured List. It uses DisclosureGroup elements for the overarching months (e.g., "September 2026") allowing them to collapse/expand. Inside, Section headers break down the days (e.g., "Monday, Sept 7"), containing standard SwiftUI rows for individual transactions.
  - **Functionality:** Accepts an optional Envelope or User filter as an initialization parameter so it can be reused dynamically across the app.

- **AutomationView.swift**
  - **Layout:** A grouped List separating automated items into sections: "Upcoming Paychecks" and "Active Subscriptions".
  - **Functionality:** Tapping the + button opens a sheet linking to either PaycheckSetupView or a simplified subscription setup flow.

- **PaycheckSetupView.swift**
  - **Layout:** Uses a Form or grouped List. Includes TextField inputs for fixed-dollar splits per envelope.
  - **Functionality:** Crucially features a dynamic sticky banner displaying the unallocatedAmount in real-time. The primary "Save" button utilizes the .disabled() modifier, becoming unclickable unless the zero-sum logic confirms the unallocated amount is exactly zero. Includes a "Sweep Remainder" button.

- **SettingsView.swift**
  - **Layout:** A standard native SwiftUI Form broken into clear sections (Profile, Cloud Sharing, Manage Accounts, Preferences).
  - **Functionality:** Houses standard TextFields for display names. Integrates the UICloudSharingController via a button tap. Contains the CRUD (Create, Read, Update, Delete) UI for managing the top-level bank accounts and their associated envelopes.

### 5. Services / Managers (Background Tasks & APIs)
*These files handle system-level integrations outside of standard UI flow.*

- **CloudSharingManager.swift**: A wrapper for Apple's UICloudSharingController, managing the generation of share links and permission levels for household members.
- **BackgroundTaskManager.swift**: Interfaces with iOS Background Tasks to silently execute recurring subscriptions and paycheck allocations on their scheduled dates without requiring the app to be open.

### 6. AI Coding Directives & Prompt Guidelines
*When supplying this document to an AI agent for code generation or debugging, the agent must adhere to the following strict guidelines:*

1. **Framework Strictness:** Use native SwiftUI exclusively for the frontend. Do NOT use third-party UI libraries or UIKit wrappers unless absolutely mandated by iOS limitations. Rely on standard components like NavigationStack, List, Form, DisclosureGroup, and Apple's native Charts framework.
2. **Architecture Enforcement:** Strictly follow the MVVM pattern outlined above. Views must remain declarative and lightweight. All business logic, array filtering, and math must live within the ViewModels. Data shaping and schema mapping must remain in the SwiftData Models.
3. **Data & Backend:** Use SwiftData natively paired with CloudKit. Do NOT suggest or implement Firebase, CoreData (without SwiftData), or other external databases. Assume automatic syncing via Apple IDs is the desired behavior for multi-user collaboration.
4. **Design Language:** Utilize Apple's native Human Interface Guidelines. Rely entirely on SF Symbols for iconography. Use native SwiftUI modifiers like .sheet, .confirmationDialog, and .navigationTitle().
5. **Zero-Sum Logic:** When generating code for paycheck allocations or transfers, math validation is paramount. Prevent user progression (e.g., using .disabled()) if the exact total of the splits does not perfectly equal the overarching income total.
6. **Code Modularity:** Prioritize code reuse. If a list of transactions is needed in multiple tabs, build a single reusable component (e.g., TransactionListView) that accepts optional filters, rather than duplicating view logic across files.

```
