# Services and ViewModels Audit Report

## Overview
This document outlines the findings from an audit of the services and view models in the Cue iOS app, focusing on AssistantService, AssistantsViewModel, and AuthService. The audit evaluates adherence to best practices in Combine, state management, and concurrency.

## Key Findings

### 1. Combine Usage

#### Current Implementation
- Basic usage of `@Published` properties
- Simple publisher-subscriber patterns
- Manual cancellable storage

#### Improvement Opportunities
1. **Structured Publisher Chains**
   ```swift
   // Current:
   assistantService.$assistants
       .sink { [weak self] assistants in
           guard let self = self else { return }
           Task {
               if !assistants.isEmpty {
                   await self.updateAssistants(with: assistants)
               }
           }
       }

   // Improved:
   assistantService.$assistants
       .filter { !$0.isEmpty }
       .receive(on: DispatchQueue.main)
       .removeDuplicates()
       .asyncMap { assistants in
           await self.updateAssistants(with: assistants)
       }
       .sink { ... }
   ```

2. **Error Handling**
   - Add proper error handling in publisher chains using `catch` and `mapError`
   - Create dedicated error publishers for better error propagation

3. **Resource Management**
   - Implement structured cancellation using `withTaskCancellationHandler`
   - Use composite cancellables for better organization

### 2. State Management

#### Current Implementation
- Direct state mutation in multiple places
- Mixed responsibility between service and view model
- Inconsistent state update patterns

#### Improvement Opportunities
1. **State Container**
   ```swift
   struct AssistantState {
       var assistants: [Assistant]
       var clientStatuses: [String: ClientStatus]
       var isLoading: Bool
       var error: Error?
       var primaryAssistant: Assistant?
       
       mutating func update(with assistants: [Assistant]) {
           self.assistants = assistants
           updatePrimaryAssistant()
       }
   }
   ```

2. **Single Source of Truth**
   - Move all state management to dedicated state containers
   - Implement unidirectional data flow
   - Use state reducers for predictable mutations

3. **State Updates**
   - Implement atomic state updates
   - Add state validation logic
   - Include state transition logging

### 3. Concurrency

#### Current Implementation
- Basic async/await usage
- Mixed usage of GCD and async/await
- Potential race conditions in state updates

#### Improvement Opportunities
1. **Structured Concurrency**
   ```swift
   // Current:
   func fetchAssistants(tag: String? = nil) async {
       isLoading = true
       do {
           _ = try await assistantService.listAssistants()
       } catch {
           self.error = error
       }
       isLoading = false
   }

   // Improved:
   func fetchAssistants(tag: String? = nil) async {
       await withTaskGroup(of: Void.self) { group in
           group.addTask { @MainActor in
               self.isLoading = true
           }
           
           do {
               let assistants = try await assistantService.listAssistants()
               await updateState(with: assistants)
           } catch {
               await handleError(error)
           }
           
           await MainActor.run {
               self.isLoading = false
           }
       }
   }
   ```

2. **Actor Usage**
   - Convert services to actors for thread-safe state management
   - Implement proper actor isolation
   - Add actor-based state synchronization

3. **Task Management**
   - Add structured task cancellation
   - Implement proper task lifecycles
   - Add task priority management

### 4. Architecture

#### Current Implementation
- Mixed responsibilities between services and view models
- Tight coupling between components
- Inconsistent error handling

#### Improvement Opportunities
1. **Service Layer**
   ```swift
   protocol AssistantServiceProtocol {
       func listAssistants() async throws -> [Assistant]
       func createAssistant(name: String, isPrimary: Bool) async throws -> Assistant
       func updateAssistant(id: String, update: AssistantUpdate) async throws -> Assistant
       func deleteAssistant(id: String) async throws
   }
   ```

2. **View Model Layer**
   - Implement proper MVVM patterns
   - Add view state management
   - Separate business logic from presentation logic

3. **Dependency Injection**
   - Add proper DI container
   - Implement service protocols
   - Add mock services for testing

## Implementation Plan

### Phase 1: State Management
1. Create state containers
2. Implement state reducers
3. Add state validation

### Phase 2: Concurrency
1. Convert services to actors
2. Implement structured concurrency
3. Add task management

### Phase 3: Combine
1. Refactor publisher chains
2. Add error handling
3. Implement resource management

### Phase 4: Architecture
1. Implement service protocols
2. Add dependency injection
3. Separate concerns

## Code Examples

### 1. State Container Implementation
```swift
actor AssistantStateContainer {
    private var state: AssistantState
    private let stateSubject = CurrentValueSubject<AssistantState, Never>
    
    var statePublisher: AnyPublisher<AssistantState, Never> {
        stateSubject.eraseToAnyPublisher()
    }
    
    func update(_ mutation: (inout AssistantState) -> Void) {
        mutation(&state)
        stateSubject.send(state)
    }
}
```

### 2. Service Protocol
```swift
protocol AssistantServiceProtocol {
    var statePublisher: AnyPublisher<AssistantState, Never> { get }
    
    func listAssistants() async throws -> [Assistant]
    func createAssistant(name: String, isPrimary: Bool) async throws -> Assistant
    func updateAssistant(id: String, update: AssistantUpdate) async throws -> Assistant
    func deleteAssistant(id: String) async throws
}
```

### 3. View Model Implementation
```swift
@MainActor
class AssistantViewModel: ObservableObject {
    @Published private(set) var state: AssistantViewState
    private let service: AssistantServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    init(service: AssistantServiceProtocol) {
        self.service = service
        setupBindings()
    }
    
    private func setupBindings() {
        service.statePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.updateViewState(with: state)
            }
            .store(in: &cancellables)
    }
    
    func updateViewState(with serviceState: AssistantState) {
        // Map service state to view state
    }
}
```

## Next Steps

1. Create GitHub issues for each improvement area
2. Prioritize improvements based on impact
3. Create test cases for new implementations
4. Plan gradual migration to new architecture
5. Document new patterns and best practices