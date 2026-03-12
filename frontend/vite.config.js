import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    host: true,
    // Allow all AWS ELB hostnames
    allowedHosts: [
      "localhost",
      "127.0.0.1",
      ".elb.amazonaws.com",
    ],
  },
});
