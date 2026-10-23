import MessageUI
import SwiftUI
import WebKit

/// "Get it all" step 2: seller by seller, in the seller's own website. The user taps Add to cart and Pay; Parchi never does.
struct CheckoutAssistantView: View {
    @State var flow: CheckoutFlow
    @State private var web = WebController()
    @State private var findMessage: String?
    @State private var showComposer = false
    @State private var showShare = false

    var body: some View {
        VStack(spacing: 0) {
            if flow.isFinished {
                summary
            } else if let step = flow.current {
                header(step)
                Divider()
                if step.kind == .web { webBody(step) } else { messageBody(step) }
                Divider()
                controls(step)
            }
        }
        .navigationTitle("Checkout Assistant")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { web.onNavigated = { flow.pageChanged(to: $0) }; openCurrent() }
        .onChange(of: flow.currentIndex) { _, _ in findMessage = nil; openCurrent() }
        .sheet(isPresented: $showComposer) {
            if let step = flow.current {
                MessageComposer(recipients: step.phone.map { [$0] } ?? [], body: step.messageBody) { result in
                    showComposer = false
                    if result == .sent { flow.markAllAdded(); flow.goToCheckout() }
                }
            }
        }
        .sheet(isPresented: $showShare) {
            if let step = flow.current {
                ShareSheet(text: step.messageBody) { completed in
                    showShare = false
                    if completed { flow.markAllAdded(); flow.goToCheckout() }
                }
            }
        }
    }

    private func openCurrent() {
        guard let step = flow.current else { return }
        if step.kind == .web, let url = step.startURL { web.load(url) }
        flow.opened()
    }

    // MARK: Pieces

    private func header(_ step: CheckoutStep) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(flow.headerText).font(.subheadline.bold())
                Spacer()
                Text(flow.currentState.label).font(.caption).foregroundStyle(.secondary)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(step.items) { item in
                        let done = flow.isAdded(item.id)
                        let focused = flow.focusedItemID == item.id
                        Button {
                            flow.focus(itemID: item.id)
                            if step.kind == .web, let url = item.productURL { web.load(url) }
                        } label: {
                            Label(item.name, systemImage: done ? "checkmark.circle.fill" : "circle")
                                .font(.footnote)
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(focused ? Color.accentColor.opacity(0.18) : Color(.secondarySystemBackground), in: Capsule())
                                .foregroundStyle(done ? Color.green : Color.primary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(item.name), \(done ? "added" : "not added yet")")
                    }
                }
            }
        }
        .padding(.horizontal).padding(.vertical, 8)
    }

    private func webBody(_ step: CheckoutStep) -> some View {
        ZStack(alignment: .top) {
            WebViewHost(controller: web)
            if web.isLoading { ProgressView().padding(8).background(.thinMaterial, in: Capsule()).padding(.top, 8) }
            if let text = web.note ?? findMessage {
                Text(text).font(.footnote).padding(8).frame(maxWidth: .infinity).background(.yellow.opacity(0.9))
            }
        }
    }

    private func messageBody(_ step: CheckoutStep) -> some View {
        List {
            Section("Send this list to \(step.sellerName)") {
                ForEach(step.items) { item in
                    HStack {
                        Image(systemName: flow.isAdded(item.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(flow.isAdded(item.id) ? .green : .secondary)
                        Text(item.name)
                        Spacer()
                        if item.isMedicine { Text("qty \(item.quantity)").foregroundStyle(.secondary).font(.footnote) }
                    }
                }
            }
            Section {
                Text(step.messageBody).font(.footnote).foregroundStyle(.secondary)
                Text("Parchi helps you write the message. You send it, and you pay the shop yourself.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    private func controls(_ step: CheckoutStep) -> some View {
        VStack(spacing: 8) {
            Text(step.kind == .web
                 ? "This is \(step.sellerName)'s real website. You tap Add to cart and Pay yourself. Parchi never clicks for you."
                 : "You send the message and pay the shop yourself.")
                .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
            if step.kind == .web {
                HStack(spacing: 8) {
                    button("Find on page", "magnifyingglass") { find() }.disabled(flow.focusedItem == nil)
                    button("Added ✓", "cart.badge.plus") { markAdded() }
                        .disabled(!(flow.currentState == .opened || flow.currentState == .itemsAdded))
                }
                HStack(spacing: 8) {
                    if flow.currentState == .atCheckout {
                        button("Ordered ✓", "checkmark.seal") { flow.markOrdered() }
                    } else {
                        button("Go to checkout", "creditcard") { flow.goToCheckout() }
                            .disabled(!(flow.currentState == .opened || flow.currentState == .itemsAdded))
                    }
                    skipButton
                }
            } else {
                HStack(spacing: 8) {
                    if flow.currentState == .atCheckout {
                        button("Shop confirmed ✓", "checkmark.seal") { flow.markOrdered() }
                    } else {
                        button(MFMessageComposeViewController.canSendText() ? "Message the shop" : "Share the list", "message") {
                            if MFMessageComposeViewController.canSendText() { showComposer = true } else { showShare = true }
                        }
                    }
                    skipButton
                }
            }
        }
        .padding().background(.bar)
    }

    private var skipButton: some View {
        button("Skip this seller", "forward.end", role: .destructive) { flow.skipCurrent() }
    }

    private func button(_ title: String, _ icon: String, role: ButtonRole? = nil, action: @escaping () -> Void) -> some View {
        Button(role: role, action: action) {
            Label(title, systemImage: icon).font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 40)
        }
        .buttonStyle(.bordered)
    }

    private func find() {
        guard let item = flow.focusedItem else { return }
        Task {
            let found = await web.highlight(item.searchText)
            findMessage = found ? nil : "Could not find \"\(item.searchText)\" on this page. Use the seller's search box."
        }
    }

    private func markAdded() {
        flow.markAdded()
        findMessage = nil
        if flow.currentState == .opened, let next = flow.focusedItem?.productURL { web.load(next) }
    }

    private var summary: some View {
        List {
            Section("Checkout finished") {
                ForEach(flow.steps) { step in
                    HStack {
                        Text(step.sellerName)
                        Spacer()
                        Text(flow.state(of: step.id).label).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

/// In-app SMS composer (real iPhone only; the Simulator cannot send SMS).
struct MessageComposer: UIViewControllerRepresentable {
    let recipients: [String]
    let body: String
    let onFinish: (MessageComposeResult) -> Void

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let controller = MFMessageComposeViewController()
        controller.recipients = recipients
        controller.body = body
        controller.messageComposeDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(onFinish) }

    final class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        let onFinish: (MessageComposeResult) -> Void
        init(_ onFinish: @escaping (MessageComposeResult) -> Void) { self.onFinish = onFinish }
        func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
            onFinish(result)
        }
    }
}

/// Share-sheet fallback where SMS is unavailable (Simulator, iPad).
struct ShareSheet: UIViewControllerRepresentable {
    let text: String
    let onFinish: (Bool) -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        controller.completionWithItemsHandler = { _, completed, _, _ in onFinish(completed) }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
