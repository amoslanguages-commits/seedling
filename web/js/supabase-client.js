/* ═══════════════════════════════════════════════════════════
   SUPABASE CLIENT INITIALIZATION
   Connects the marketing website to the real Seedling data.
═══════════════════════════════════════════════════════════ */

const SUPABASE_URL = 'https://ikhvhivwqsbgiknhvxbq.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlraHZoaXZ3cXNiZ2lrbmh2eGJxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQwNzQ3NjksImV4cCI6MjA4OTY1MDc2OX0.e_aHX3Gg9eijznm_2qbNfUxf63_YYDyvGuYsfPUHwD0';

// Initialize the Supabase client
const client = supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

window.supabaseClient = client;
window.sb = client; 
