import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "PromptMe | Notch-first macOS Teleprompter",
  description:
    "PromptMe keeps your script in a notch overlay with smooth auto-scroll, privacy-safe sharing, and multi-display support.",
  icons: {
    icon: "/promptme-app-icon.png",
    shortcut: "/promptme-app-icon.png",
    apple: "/promptme-app-icon.png",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body className="pm-root-body">{children}</body>
    </html>
  );
}
