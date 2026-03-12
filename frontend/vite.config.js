import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    host: true,
    // Allow current ELB hostname and future ELB hostnames in this AWS region.
    allowedHosts: [
      "localhost",
      "127.0.0.1",
      "abea0c534cf09460fabbd69584a81815-383028599.ap-south-1.elb.amazonaws.com",
      ".ap-south-1.elb.amazonaws.com",
    ],
  },
});
