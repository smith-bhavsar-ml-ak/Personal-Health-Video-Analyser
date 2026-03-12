import type { Metadata } from "next";
import "./globals.css";
import Sidebar from "@/components/layout/Sidebar";
import Header from "@/components/layout/Header";
import { ThemeProvider } from "@/contexts/ThemeContext";

export const metadata: Metadata = {
  title: "Personal Health Video Analyzer",
  description: "AI-powered workout analysis and coaching",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    // suppressHydrationWarning: the anti-flash script below adds "light" class
    // before React hydrates, so the server/client HTML will intentionally differ.
    <html lang="en" suppressHydrationWarning>
      {/* Inline script runs synchronously before paint — prevents flash of wrong theme */}
      <head>
        <script dangerouslySetInnerHTML={{ __html: `
          try {
            if (localStorage.getItem('theme') === 'light')
              document.documentElement.classList.add('light');
          } catch(e) {}
        ` }} />
      </head>
      <body className="bg-bg text-text-primary flex h-screen overflow-hidden">
        <ThemeProvider>
          <Sidebar />
          <div className="flex flex-col flex-1 overflow-hidden">
            <Header />
            <main className="flex-1 overflow-y-auto px-8 py-6">
              {children}
            </main>
          </div>
        </ThemeProvider>
      </body>
    </html>
  );
}
