//
//  SettingsView.swift
//  ReceiptBox
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("rb.faceIDLock") private var faceIDLockEnabled = false
    @AppStorage("rb.iCloudSync") private var iCloudSyncEnabled = false
    @AppStorage("rb.previewEmptyState") private var previewEmptyState = false
    @State private var showComingSoonAlert = false

    var body: some View {
        NavigationStack {
            List {
                profileSection
                securitySection
                proSection
                privacySection
                developerSection
            }
            .navigationTitle("설정")
            .alert("출시 예정", isPresented: $showComingSoonAlert) {
                Button("확인", role: .cancel) {}
            }
        }
    }

    private var profileSection: some View {
        Section {
            HStack(spacing: Spacing.m) {
                Circle()
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 52, height: 52)
                    .overlay {
                        Image(systemName: "person.fill")
                            .foregroundStyle(Color.accentColor)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text("이름을 설정해주세요")
                        .font(RBFont.headline)
                    Text("프로필을 설정해보세요")
                        .font(RBFont.caption)
                        .foregroundStyle(Color.rbTextSecondary)
                }
            }
            .padding(.vertical, Spacing.xs)
            .accessibilityElement(children: .combine)
        }
    }

    private var securitySection: some View {
        Section {
            Toggle(isOn: $faceIDLockEnabled) {
                Label("Face ID 잠금", systemImage: "faceid")
            }
            .disabled(true)

            Toggle(isOn: $iCloudSyncEnabled) {
                Label("iCloud 동기화", systemImage: "icloud.fill")
            }
            .disabled(true)
        } header: {
            Text("보안 및 동기화")
        } footer: {
            Text("Face ID 잠금과 iCloud 동기화는 다음 업데이트에서 제공될 예정이에요.")
        }
    }

    private var proSection: some View {
        Section {
            Button {
                showComingSoonAlert = true
            } label: {
                HStack(spacing: Spacing.m) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("ReceiptBox PRO")
                            .font(RBFont.headline)
                            .foregroundStyle(Color.rbTextPrimary)
                        Text("고급 분석 기능과 다양한 혜택을 만나보세요")
                            .font(RBFont.caption)
                            .foregroundStyle(Color.rbTextSecondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(Color.rbTextTertiary)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var privacySection: some View {
        Section("개인정보 보호") {
            Button {
                showComingSoonAlert = true
            } label: {
                Label("개인정보 처리방침", systemImage: "hand.raised.fill")
            }
            .buttonStyle(.plain)

            Button {
                showComingSoonAlert = true
            } label: {
                Label("이용약관", systemImage: "doc.text.fill")
            }
            .buttonStyle(.plain)
        }
    }

    private var developerSection: some View {
        Section {
            Toggle("빈 상태 미리보기", isOn: $previewEmptyState)
        } header: {
            Text("개발자 옵션")
        } footer: {
            Text("영수증이 없는 첫 실행 화면을 테스트하기 위해 홈 화면을 임시로 비워서 보여줘요.")
        }
    }
}

#Preview {
    SettingsView()
}
