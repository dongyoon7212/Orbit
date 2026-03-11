export default {
  async fetch(request, env) {
    // CORS
    if (request.method === 'OPTIONS') {
      return new Response(null, {
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'POST, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type',
        }
      });
    }

    const url = new URL(request.url);

    // Claude API 프록시
    if (url.pathname === '/claude') {
      const body = await request.json();
      const response = await fetch('https://api.anthropic.com/v1/messages', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': env.ANTHROPIC_API_KEY,
          'anthropic-version': '2023-06-01',
        },
        body: JSON.stringify(body),
      });
      const data = await response.json();
      return Response.json(data, {
        headers: { 'Access-Control-Allow-Origin': '*' }
      });
    }

    // NASA API 프록시
    if (url.pathname === '/nasa') {
      const params = url.searchParams.toString();
      const response = await fetch(
        `https://api.nasa.gov/planetary/apod?api_key=${env.NASA_API_KEY}&${params}`
      );
      const data = await response.json();
      return Response.json(data, {
        headers: { 'Access-Control-Allow-Origin': '*' }
      });
    }

    return new Response('Not found', { status: 404 });
  }
};