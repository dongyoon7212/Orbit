// CertificationSelectView.swift
// Orbit — 온보딩 1단계: 자격증 선택

import SwiftUI

struct CertificationSelectView: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        OnboardingLayout(viewModel: viewModel, content: {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(viewModel.availableCertifications) { cert in
                        CertificationCard(
                            cert: cert,
                            isSelected: viewModel.selectedCertificationId == cert.id
                        )
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3)) {
                                viewModel.selectedCertificationId = cert.id
                                viewModel.selectedCertificationName = cert.name
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 32)
            }
        }, nextButtonTitle: "선택 완료", onNext: viewModel.goNext)
    }
}

struct CertificationCard: View {
    let cert: CertificationDTO
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 16) {
            // 아이콘
            ZStack {
                Circle()
                    .fill(isSelected ? Color.white : Color.white.opacity(0.1))
                    .frame(width: 52, height: 52)

                Image(systemName: "doc.badge.gearshape")
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? Color(red: 0.08, green: 0.05, blue: 0.22) : .white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(cert.name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)

                Text("\(cert.organization) · \(cert.basedOn)")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.6))

                HStack(spacing: 8) {
                    Label("\(cert.planets.count)개 행성", systemImage: "globe")
                    Label("약 \(cert.totalChapterCount)챕터", systemImage: "list.bullet")
                }
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.5))
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.white)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isSelected ? Color.white.opacity(0.2) : Color.white.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isSelected ? Color.white.opacity(0.6) : Color.clear, lineWidth: 1.5)
                )
        )
    }
}
