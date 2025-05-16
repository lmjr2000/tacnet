
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders })
  }
  
  try {
    const { sender_id, recipient_id, message_text, item_id } = await req.json()
    
    if (!sender_id || !recipient_id || !message_text) {
      return new Response(
        JSON.stringify({ error: 'Sender ID, recipient ID, and message text are required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }
    
    // Create a Supabase client
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      {
        global: { headers: { Authorization: req.headers.get('Authorization')! } },
      }
    )

    // Verify the sender's authentication
    const {
      data: { user },
    } = await supabaseClient.auth.getUser(req.headers.get('Authorization')!)

    if (!user || user.id !== sender_id) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }
    
    // Send the message
    const { data, error } = await supabaseClient
      .from('direct_messages')
      .insert([
        { 
          sender_id, 
          recipient_id, 
          message: message_text, 
          item_id: item_id || null,
          is_read: false 
        }
      ])
      .select()
    
    if (error) throw error
    
    // Return the new message
    return new Response(
      JSON.stringify(data[0]),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
    
  } catch (error) {
    console.error('Message send error:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
