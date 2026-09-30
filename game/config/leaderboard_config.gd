extends RefCounted

# Global Top-10 backend.
# The public publishable key enables the shared leaderboard for browser clients.
# Never place a secret/service_role key here.
const SUPABASE_URL := "https://jcqnzrsrnnvpusyznpye.supabase.co"
const SUPABASE_ANON_KEY := "sb_publishable_gVzVGZCEtFpJUCFrTJLM2g_enGnvg03"

const TABLE_NAME := "leaderboard"
