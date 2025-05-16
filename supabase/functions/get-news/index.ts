
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { query = "firearms", category = null } = await req.json();
    
    // Get the API key from environment variables
    const apiKey = Deno.env.get('SERPAPI_KEY');
    
    if (!apiKey) {
      throw new Error('SERPAPI_KEY is not set in environment variables');
    }
    
    // Base URL for SerpAPI Google News
    let url = `https://serpapi.com/search?engine=google_news&api_key=${apiKey}`;
    
    // Add query if not using a topic token
    if (category) {
      // Using a topic token (categories like "World", "Business", etc.)
      url += `&topic_token=${category}`;
    } else {
      // Using a search query
      url += `&q=${encodeURIComponent(query)}`;
    }
    
    // Add locale parameters
    url += "&gl=us&hl=en";
    
    console.log(`Fetching news from: ${url.replace(apiKey, '[REDACTED]')}`);
    
    // Fetch data from SerpAPI
    const response = await fetch(url);
    
    if (!response.ok) {
      throw new Error(`SerpAPI request failed: ${response.status} ${response.statusText}`);
    }
    
    const data = await response.json();
    
    return new Response(
      JSON.stringify(data),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (error) {
    console.error("Error fetching news:", error.message);
    
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  }
});
