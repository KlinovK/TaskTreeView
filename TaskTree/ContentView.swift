//
//  ContentView.swift
//  TaskTree
//
//  Created by Константин Клинов on 11/03/26.
//

import SwiftUI
import Combine

// MARK: - Priority

enum TaskPriority: Int, CaseIterable, Comparable {
    case low = 0, medium = 1, high = 2, critical = 3

    static func < (lhs: TaskPriority, rhs: TaskPriority) -> Bool { lhs.rawValue < rhs.rawValue }

    var label: String {
        switch self {
        case .low:      return "Low"
        case .medium:   return "Medium"
        case .high:     return "High"
        case .critical: return "Critical"
        }
    }

    var color: Color {
        switch self {
        case .low:      return .gray
        case .medium:   return .blue
        case .high:     return .orange
        case .critical: return .red
        }
    }

    var icon: String {
        switch self {
        case .low:      return "arrow.down.circle"
        case .medium:   return "minus.circle"
        case .high:     return "arrow.up.circle"
        case .critical: return "exclamationmark.2"
        }
    }
}

// MARK: - Status

enum TaskStatus {
    case notStarted, inProgress, completed, cancelled

    var color: Color {
        switch self {
        case .notStarted: return Color(.systemGray3)
        case .inProgress: return .blue
        case .completed:  return .green
        case .cancelled:  return .red
        }
    }

    var icon: String {
        switch self {
        case .notStarted: return "circle"
        case .inProgress: return "clock.fill"
        case .completed:  return "checkmark.circle.fill"
        case .cancelled:  return "xmark.circle.fill"
        }
    }

    var label: String {
        switch self {
        case .notStarted: return "Pending"
        case .inProgress: return "In Progress"
        case .completed:  return "Done"
        case .cancelled:  return "Cancelled"
        }
    }
}

// MARK: - Task Node

class TaskNode: ObservableObject, Identifiable {
    let id = UUID()
    let title: String

    /// The priority explicitly assigned to this node
    @Published var ownPriority: TaskPriority
    /// Effective priority after inheritance from parent
    @Published var effectivePriority: TaskPriority
    /// Whether current effective priority was inherited (not own)
    @Published var priorityWasInherited: Bool = false

    @Published var status: TaskStatus
    @Published var isExpanded: Bool
    @Published var isCancelled: Bool = false

    var children: [TaskNode]
    weak var parent: TaskNode?

    init(
        title: String,
        priority: TaskPriority = .medium,
        status: TaskStatus = .notStarted,
        children: [TaskNode] = [],
        isExpanded: Bool = true
    ) {
        self.title = title
        self.ownPriority = priority
        self.effectivePriority = priority
        self.status = status
        self.children = children
        self.isExpanded = isExpanded
        for child in children { child.parent = self }
    }

    // MARK: Priority Inheritance
    /// Push effective priority downward to every descendant whose own
    /// priority is lower — this prevents priority inversion.
    func propagatePriority() {
        for child in children {
            let shouldInherit = effectivePriority > child.ownPriority
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                child.effectivePriority  = shouldInherit ? effectivePriority : child.ownPriority
                child.priorityWasInherited = shouldInherit
            }
            child.propagatePriority()
        }
    }

    // MARK: Cancellation Propagation
    /// Cancel this node and cascade the cancellation to every descendant,
    /// with a small staggered delay so the waterfall is visible.
    func cancelCascade(delay: Double = 0) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                self.isCancelled = true
                if self.status != .completed { self.status = .cancelled }
            }
            for (i, child) in self.children.enumerated() {
                child.cancelCascade(delay: Double(i + 1) * 0.07)
            }
        }
    }

    /// Restore the full subtree (undo cancel demo).
    func restoreCascade() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            isCancelled = false
            if status == .cancelled { status = .notStarted }
        }
        children.forEach { $0.restoreCascade() }
    }
}

// MARK: - Sample Data

extension TaskNode {
    static var sampleTree: TaskNode {
        let root = TaskNode(title: "Launch Mobile App v2.0", priority: .high, status: .inProgress, children: [
            TaskNode(title: "Design", priority: .medium, status: .completed, children: [
                TaskNode(title: "Wireframes",       priority: .low,    status: .completed),
                TaskNode(title: "UI Components",    priority: .medium, status: .completed),
                TaskNode(title: "Prototype Review", priority: .low,    status: .completed)
            ]),
            TaskNode(title: "Backend", priority: .medium, status: .inProgress, children: [
                TaskNode(title: "Auth API",              priority: .high,   status: .completed),
                TaskNode(title: "User Profile API",      priority: .medium, status: .inProgress),
                TaskNode(title: "Push Notifications",    priority: .low,    status: .notStarted),
                TaskNode(title: "Analytics Integration", priority: .low,    status: .notStarted)
            ]),
            TaskNode(title: "iOS Development", priority: .medium, status: .inProgress, children: [
                TaskNode(title: "Onboarding Flow", priority: .high,   status: .completed),
                TaskNode(title: "Home Screen",     priority: .medium, status: .inProgress, children: [
                    TaskNode(title: "Feed Component", priority: .low, status: .inProgress),
                    TaskNode(title: "Search Bar",     priority: .low, status: .notStarted)
                ]),
                TaskNode(title: "Settings Screen", priority: .low, status: .notStarted),
                TaskNode(title: "Dark Mode",        priority: .low, status: .notStarted)
            ]),
            TaskNode(title: "QA & Testing", priority: .low, status: .notStarted, children: [
                TaskNode(title: "Unit Tests",   priority: .low, status: .notStarted),
                TaskNode(title: "UI Tests",     priority: .low, status: .notStarted),
                TaskNode(title: "Beta Testing", priority: .low, status: .notStarted)
            ])
        ])
        return root
    }
}

// MARK: - Priority Badge

struct PriorityBadge: View {
    let priority: TaskPriority
    let inherited: Bool

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: priority.icon)
                .font(.system(size: 9, weight: .bold))
            Text(priority.label)
                .font(.system(size: 9, weight: .semibold))
            if inherited {
                Image(systemName: "arrow.down.left")
                    .font(.system(size: 8, weight: .bold))
                    .opacity(0.8)
            }
        }
        .foregroundColor(priority.color)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(priority.color.opacity(inherited ? 0.18 : 0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .strokeBorder(inherited ? priority.color.opacity(0.45) : .clear, lineWidth: 1)
                )
        )
        .transition(.scale(scale: 0.7).combined(with: .opacity))
    }
}

// MARK: - Task Row

struct TaskRowView: View {
    @ObservedObject var node: TaskNode
    let depth: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                indentGuides

                // Expand / collapse
                if !node.children.isEmpty {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            node.isExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: node.isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                            .frame(width: 14, height: 14)
                    }
                    .buttonStyle(.plain)
                } else {
                    Spacer().frame(width: 14)
                }

                // Status icon
                Image(systemName: node.status.icon)
                    .font(.system(size: 13))
                    .foregroundColor(node.isCancelled ? .red : node.status.color)
                    .frame(width: 16)

                // Title
                Text(node.title)
                    .font(depth == 0 ? .headline : .subheadline)
                    .fontWeight(depth == 0 ? .bold : depth == 1 ? .semibold : .regular)
                    .foregroundColor(node.isCancelled ? .secondary : .primary)
                    .strikethrough(node.status == .cancelled || node.status == .completed,
                                   color: node.status == .cancelled ? .red.opacity(0.6) : .secondary)
                    .opacity(node.isCancelled ? 0.55 : 1.0)
                    .animation(.easeOut(duration: 0.25), value: node.isCancelled)

                Spacer()

                // Priority badge
                PriorityBadge(
                    priority: node.effectivePriority,
                    inherited: node.priorityWasInherited
                )
                .id("badge-\(node.id)-\(node.effectivePriority.rawValue)")
            }
            .padding(.vertical, 7)
            .padding(.trailing, 10)
            .padding(.leading, 4)
            .background(rowBackground)
            .overlay(
                node.isCancelled
                    ? RoundedRectangle(cornerRadius: 8)
                        .fill(Color.red.opacity(0.05))
                        .padding(.horizontal, 6)
                    : nil
            )
            .cornerRadius(8)
            .padding(.horizontal, 6)

            // Children
            if node.isExpanded {
                ForEach(node.children) { child in
                    TaskRowView(node: child, depth: depth + 1)
                }
            }
        }
    }

    private var indentGuides: some View {
        HStack(spacing: 0) {
            ForEach(0..<depth, id: \.self) { _ in
                Color(.systemGray4)
                    .frame(width: 1)
                    .padding(.leading, 10)
                    .padding(.trailing, 10)
            }
        }
    }

    private var rowBackground: some View {
        Group {
            if depth == 0 {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.secondarySystemBackground))
            } else {
                Color.clear
            }
        }
    }
}

// MARK: - Principle Card

struct PrincipleCard: View {
    let number: String
    let title: String
    let description: String
    let accentColor: Color
    let actionLabel: String
    let actionIcon: String
    let isActive: Bool
    let action: () -> Void
    let reset: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Text(number)
                    .font(.system(size: 11, weight: .black))
                    .foregroundColor(.white)
                    .frame(width: 22, height: 22)
                    .background(accentColor)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.bold)
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 8) {
                Button(action: action) {
                    Label(isActive ? "Applied ✓" : actionLabel,
                          systemImage: isActive ? "checkmark.seal.fill" : actionIcon)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(isActive ? Color.green : accentColor)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(isActive)
                .animation(.easeInOut(duration: 0.2), value: isActive)

                Button(action: reset) {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(accentColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(accentColor.opacity(0.1))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(isActive ? accentColor.opacity(0.5) : .clear, lineWidth: 1.5)
                )
        )
        .animation(.easeInOut(duration: 0.25), value: isActive)
    }
}

// MARK: - Priority Picker Sheet

struct PriorityPickerSheet: View {
    @ObservedObject var root: TaskNode
    @Binding var showSheet: Bool
    @Binding var inheritanceApplied: Bool

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Pick a new priority for the root task.\nAny child whose own priority is lower will automatically inherit it — preventing priority inversion.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)

                VStack(spacing: 10) {
                    ForEach(TaskPriority.allCases.reversed(), id: \.rawValue) { p in
                        Button {
                            withAnimation {
                                root.ownPriority = p
                                root.effectivePriority = p
                                root.priorityWasInherited = false
                                root.propagatePriority()
                                inheritanceApplied = true
                            }
                            showSheet = false
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: p.icon)
                                    .foregroundColor(p.color)
                                    .frame(width: 22)
                                Text(p.label)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                Spacer()
                                if root.ownPriority == p {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                        .fontWeight(.semibold)
                                }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(p.color.opacity(0.08))
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)
                    }
                }
                Spacer()
            }
            .padding(.top, 20)
            .navigationTitle("Set Root Priority")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { showSheet = false }
                }
            }
        }
    }
}

// MARK: - Main Task Tree View

struct TaskTreeView: View {
    @StateObject private var root = TaskNode.sampleTree
    @State private var inheritanceApplied = false
    @State private var cancellationApplied = false
    @State private var showPrioritySheet = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {

                    // Principle cards
                    VStack(spacing: 10) {
                        PrincipleCard(
                            number: "1",
                            title: "Priority Inheritance",
                            description: "Children inherit the parent's higher priority, preventing priority inversion.",
                            accentColor: .orange,
                            actionLabel: "Set Root Priority",
                            actionIcon: "arrow.up.circle.fill",
                            isActive: inheritanceApplied,
                            action: { showPrioritySheet = true },
                            reset: {
                                withAnimation { resetPriorities(root); inheritanceApplied = false }
                            }
                        )

                        PrincipleCard(
                            number: "2",
                            title: "Cancellation Propagation",
                            description: "Cancelling a parent cascades instantly through the entire subtree.",
                            accentColor: .red,
                            actionLabel: "Cancel Root Task",
                            actionIcon: "xmark.circle.fill",
                            isActive: cancellationApplied,
                            action: {
                                root.cancelCascade()
                                withAnimation { cancellationApplied = true }
                            },
                            reset: {
                                root.restoreCascade()
                                withAnimation { cancellationApplied = false }
                            }
                        )
                    }
                    .padding(.horizontal, 14)

                    // Legend when inheritance is active
                    if inheritanceApplied {
                        HStack(spacing: 5) {
                            Image(systemName: "info.circle")
                                .font(.caption2)
                                .foregroundColor(.orange)
                            Text("Badge with ↙ = priority inherited from parent")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 20)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // Tree
                    VStack(alignment: .leading, spacing: 2) {
                        TaskRowView(node: root, depth: 0)
                    }
                    .padding(.bottom, 30)
                }
                .padding(.top, 12)
                .animation(.easeInOut(duration: 0.2), value: inheritanceApplied)
            }
            .navigationTitle("Task Tree")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Expand All")   { setExpanded(root, true) }
                        Button("Collapse All") { setExpanded(root, false) }
                    } label: {
                        Image(systemName: "list.bullet.indent")
                    }
                }
            }
        }
        .sheet(isPresented: $showPrioritySheet) {
            PriorityPickerSheet(
                root: root,
                showSheet: $showPrioritySheet,
                inheritanceApplied: $inheritanceApplied
            )
        }
    }

    private func setExpanded(_ node: TaskNode, _ expanded: Bool) {
        withAnimation(.spring(response: 0.3)) {
            node.isExpanded = expanded
            node.children.forEach { setExpanded($0, expanded) }
        }
    }

    private func resetPriorities(_ node: TaskNode) {
        node.effectivePriority = node.ownPriority
        node.priorityWasInherited = false
        node.children.forEach { resetPriorities($0) }
    }
}

// MARK: - Preview

struct TaskTreeView_Previews: PreviewProvider {
    static var previews: some View {
        TaskTreeView()
    }
}



