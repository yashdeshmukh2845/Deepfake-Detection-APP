import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://jkmaglmvuiyjowcispcp.supabase.co';
const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImprbWFnbG12dWl5am93Y2lzcGNwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU0MDUyMTUsImV4cCI6MjA5MDk4MTIxNX0.VA44tFbFtC5JZFpWzXHCxtcJgpt8FBXL5HyeGZRj7uo';

export const supabase = createClient(supabaseUrl, supabaseAnonKey);
