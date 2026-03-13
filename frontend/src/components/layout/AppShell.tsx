"use client";
import { useEffect } from "react";
import { usePathname, useRouter } from "next/navigation";
import Sidebar from "./Sidebar";
import Header from "./Header";
import { isLoggedIn } from "@/lib/auth";

const AUTH_ROUTES = ["/login"];

export default function AppShell({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const router = useRouter();
  const isAuthRoute = AUTH_ROUTES.includes(pathname);

  useEffect(() => {
    if (!isAuthRoute && !isLoggedIn()) {
      router.replace("/login");
    }
  }, [pathname, isAuthRoute, router]);

  if (isAuthRoute) {
    return <div className="flex-1 overflow-hidden">{children}</div>;
  }

  return (
    <>
      <Sidebar />
      <div className="flex flex-col flex-1 overflow-hidden">
        <Header />
        <main className="flex-1 overflow-y-auto px-8 py-6">
          {children}
        </main>
      </div>
    </>
  );
}
