import SwiftUI

struct AboutSettingsView: View {
    @State private var isCheckingUpdate = false
    @State private var autoCheckUpdates = UpdateChecker.defaultAutoCheckUpdatesEnabled(userDefaults: .standard)
    @State private var updateChannel = UpdateChecker.shared.selectedUpdateChannel

    var body: some View {
        VStack(spacing: 0) {
            brandHeader
                .padding(.top, 8)

            connectSection
                .padding(.top, 20)

            updateSection
                .padding(.top, 12)
                .padding(.bottom, 12)
        }
        .padding(.horizontal, 30)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    // MARK: - Brand Header

    private var brandHeader: some View {
        VStack(spacing: 10) {
            if let icon = NSApp.applicationIconImage {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 72, height: 72)
            }

            Text("Calendar Pro")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            Text(L("macOS Menu Bar Calendar"))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                Text("v\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0")")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)

                Text("·")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary.opacity(0.6))

                Text("by Yelog")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
    }

    // MARK: - Connect Section

    private var connectSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L("Links"))
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary.opacity(0.8))
                .tracking(0.5)

            // GitHub Star Banner
            Button {
                if let url = URL(string: "https://github.com/yelog/calendar-pro") {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                VStack(spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.yellow)

                        Text(L("Star on GitHub"))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.primary)
                    }

                    Text(L("Star Support Message"))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.yellow.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Color.yellow.opacity(0.25), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)

            // Social links
            VStack(spacing: 0) {
                AboutSocialLinkRow(
                    icon: "curlybraces",
                    title: "GitHub",
                    urlString: "https://github.com/yelog/calendar-pro"
                )

                Divider()
                    .padding(.horizontal, 12)

                AboutSocialLinkRow(
                    icon: "envelope.fill",
                    title: "Email",
                    urlString: "mailto:yelogeek@gmail.com"
                )
            }
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
            )
        }
    }

    // MARK: - Update Section

    private var updateSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L("Updates"))
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary.opacity(0.8))
                .tracking(0.5)

            VStack(alignment: .leading, spacing: 10) {
                Toggle(L("Check Automatically for Updates"), isOn: $autoCheckUpdates)
                    .font(.system(size: 13))
                    .onChange(of: autoCheckUpdates) {
                        UpdateChecker.shared.automaticallyChecksForUpdates = autoCheckUpdates
                    }

                Picker(L("Update Channel"), selection: $updateChannel) {
                    ForEach(UpdateChannel.allCases, id: \.self) { channel in
                        Text(channel.title).tag(channel)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: updateChannel) {
                    UpdateChecker.shared.selectedUpdateChannel = updateChannel
                }

                Text(L("Update Channel Description"))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.green)
                        Text("v\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0")")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        isCheckingUpdate = true
                        UpdateChecker.shared.checkForUpdates(silent: false)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            isCheckingUpdate = false
                        }
                    } label: {
                        HStack(spacing: 4) {
                            if isCheckingUpdate {
                                ProgressView()
                                    .controlSize(.small)
                                    .scaleEffect(0.6)
                            } else {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 10))
                            }
                            Text(L("Check for Updates"))
                        }
                        .font(.system(size: 11))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(isCheckingUpdate)
                }
                .padding(.leading, 22)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
            )
        }
    }
}

// MARK: - Social Link Row

private struct AboutSocialLinkRow: View {
    let icon: String
    let title: String
    let urlString: String

    @State private var isHovered = false

    var body: some View {
        Button {
            if let url = URL(string: urlString) {
                NSWorkspace.shared.open(url)
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(width: 20)

                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)

                Spacer()

                Image(systemName: "arrow.up.forward")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary.opacity(0.5))
                    .opacity(isHovered ? 1 : 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}
