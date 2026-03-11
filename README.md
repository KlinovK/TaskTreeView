# TaskTree

TaskTree is a SwiftUI demo application that visualizes hierarchical tasks as an interactive tree structure. It demonstrates two core task-management principles: Priority Inheritance and Cancellation Propagation.

Each task can contain subtasks, forming a nested tree. When a parent task’s priority is increased, lower-priority children automatically inherit the higher priority to prevent priority inversion. Likewise, cancelling a parent task cascades the cancellation through all of its descendants.

The project focuses on clean state management with ObservableObject, smooth SwiftUI animations, and clear visualization of task relationships, priorities, and statuses.

Key features
	•	Hierarchical task tree with expand/collapse
	•	Priority inheritance across task descendants
	•	Cancellation cascading through the task hierarchy
	•	Animated state transitions
	•	Visual priority badges and status indicators

This project serves as a conceptual demonstration of task dependency management and scheduling principles implemented with SwiftUI.
