//
//  RootTabView.swift
//  ReceiptBox
//
//  Scan is the app's signature action, so its tab doesn't host a page —
//  selecting it immediately presents the full-screen scan experience and
//  the tab bar reverts to whichever tab was active before.

import SwiftUI
import SwiftData

struct RootTabView: View {
    private enum RootTab: Hashable {
        case home, scan, analytics, settings
    }

    private enum AddFlow: Identifiable {
        case scan
        case barcodeScan
        case manualEntry

        var id: Self { self }
    }

    let modelContainer: ModelContainer
    @State private var store: ReceiptStore
    @State private var productStore: ProductStore

    @State private var selectedTab: RootTab = .home
    @State private var lastNonScanTab: RootTab = .home
    @State private var isShowingAddOptions = false
    @State private var addFlow: AddFlow?

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer

        let store = ReceiptStore(modelContext: ModelContext(modelContainer))
        store.seedSampleDataIfNeeded()

        // A separate ModelContext from ReceiptStore's — Product/Purchase
        // have no SwiftData relationship back to Receipt/ReceiptItem, so
        // there's no need for the two stores to share one.
        let productStore = ProductStore(modelContext: ModelContext(modelContainer))
        productStore.seedSampleDataIfNeeded()

        // The one place the two stores are wired together: whenever a
        // receipt is deleted, drop any purchases tied to it too, so no UI
        // call site has to remember to make both calls itself.
        store.onReceiptDeleted = { [productStore] receiptID in
            productStore.deletePurchases(forReceipt: receiptID)
        }

        _store = State(initialValue: store)
        _productStore = State(initialValue: productStore)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("홈", systemImage: "house.fill", value: .home) {
                HomeView(onScanTapped: presentAddOptions)
            }
            Tab("스캔", systemImage: "viewfinder", value: .scan) {
                Color.clear
            }
            Tab("분석", systemImage: "chart.pie.fill", value: .analytics) {
                AnalyticsView()
            }
            Tab("설정", systemImage: "gearshape.fill", value: .settings) {
                SettingsView()
            }
        }
        .environment(store)
        .environment(productStore)
        .onChange(of: selectedTab) { _, newValue in
            if newValue == .scan {
                selectedTab = lastNonScanTab
                presentAddOptions()
            } else {
                lastNonScanTab = newValue
            }
        }
        .sheet(isPresented: $isShowingAddOptions) {
            AddReceiptOptionsView(
                onSelectReceiptScan: {
                    isShowingAddOptions = false
                    addFlow = .scan
                },
                onSelectBarcodeScan: {
                    isShowingAddOptions = false
                    addFlow = .barcodeScan
                },
                onSelectManualEntry: {
                    isShowingAddOptions = false
                    addFlow = .manualEntry
                }
            )
            .presentationDetents([.medium])
        }
        .fullScreenCover(item: $addFlow) { flow in
            Group {
                switch flow {
                case .scan:
                    ScanView()
                case .barcodeScan:
                    BarcodeScannerView()
                case .manualEntry:
                    ManualReceiptEntryView()
                }
            }
            .environment(store)
            .environment(productStore)
        }
    }

    private func presentAddOptions() {
        isShowingAddOptions = true
    }
}

#Preview {
    RootTabView(modelContainer: try! ModelContainer(
        for: ReceiptEntity.self, ReceiptItemEntity.self, ProductEntity.self, PurchaseEntity.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    ))
}
