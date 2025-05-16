// Follow this setup guide to integrate the Deno runtime into your application:
// https://deno.land/manual/examples/supabase_functions

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// The OpenAI API endpoint for the Vision API
const OPENAI_API_ENDPOINT = "https://api.openai.com/v1/chat/completions";

// Initialize Supabase client
const supabaseClient = createClient(
  Deno.env.get("SUPABASE_URL") ?? "",
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
);

/**
 * AI-powered firearm image analysis function
 * 
 * This function uses OpenAI's Vision API to analyze images of firearms and identify:
 * - Make (manufacturer)
 * - Model
 * - Caliber
 * - Type of firearm
 * - Additional details
 * 
 * It returns a confidence score and detailed analysis.
 */
serve(async (req) => {
  try {
    // Handle CORS preflight requests
    if (req.method === "OPTIONS") {
      return new Response(null, {
        headers: {
          "Access-Control-Allow-Origin": "*",
          "Access-Control-Allow-Methods": "POST, OPTIONS",
          "Access-Control-Allow-Headers": "Content-Type, Authorization",
        },
      });
    }

    // Get the API key from environment variables
    const apiKey = Deno.env.get("OPENAI_API_KEY");
    if (!apiKey) {
      return new Response(
        JSON.stringify({ error: "OpenAI API key not configured" }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }

    // Parse request body
    const requestData = await req.json();
    const { imageUrl } = requestData;

    console.log("Received image URL type:", typeof imageUrl);
    console.log("Image URL starts with:", imageUrl?.substring?.(0, 30));

    if (!imageUrl) {
      return new Response(
        JSON.stringify({ error: "No image URL provided" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    // Prepare the OpenAI API request
    const openAIRequest = {
      model: "gpt-4-vision-preview",
      messages: [
        {
          role: "system", 
          content: "You are a firearms identification expert assistant. Your task is to identify firearms from images with high precision. Focus on determining the make, model, caliber, and type of the firearm. Provide confidence levels for your identifications."
        },
        {
          role: "user",
          content: [
            { type: "text", text: "Identify this firearm. Include the make (manufacturer), model, caliber if visible, and type of firearm (pistol, rifle, shotgun, etc.). If you're unsure about any detail, indicate your confidence level." },
            { type: "image_url", image_url: imageUrl }
          ]
        }
      ],
      max_tokens: 500,
      temperature: 0.3,
      response_format: { type: "json_object" }
    };

    // Call the OpenAI API
    const openAIResponse = await fetch(OPENAI_API_ENDPOINT, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${apiKey}`
      },
      body: JSON.stringify(openAIRequest)
    });

    // Handle non-200 responses from OpenAI
    if (!openAIResponse.ok) {
      const errorText = await openAIResponse.text();
      console.error("OpenAI API error:", errorText);
      return new Response(
        JSON.stringify({ error: "Error calling OpenAI API", details: errorText }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }

    // Parse the OpenAI response
    const openAIData = await openAIResponse.json();
    const responseContent = openAIData.choices[0].message.content;
    const parsedContent = JSON.parse(responseContent);

    // Process the AI results
    const result = {
      make: parsedContent.make || "",
      model: parsedContent.model || "",
      caliber: parsedContent.caliber || "",
      type: parsedContent.type || "",
      confidence: parsedContent.confidence || 0.5,
      additionalInfo: parsedContent.additional_info || parsedContent.notes || ""
    };

    // Return the results
    return new Response(
      JSON.stringify(result),
      { 
        headers: { 
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*"
        } 
      }
    );

  } catch (error) {
    console.error("Error in analyze-firearm-image function:", error);
    
    return new Response(
      JSON.stringify({ error: "Internal server error", message: error.message }),
      { 
        status: 500, 
        headers: { 
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*"
        } 
      }
    );
  }
}); 