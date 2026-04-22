import { config } from '../config';
import { AppError } from '../errors/AppError';

const BASE = 'https://api.elevenlabs.io/v1';

export async function handleElevenLabsFailure(
  res: Response,
  context: string
): Promise<never> {
  const retryAfter = res.headers.get('retry-after');
  if (res.status === 429) {
    throw new AppError(
      503,
      'Voice service temporarily unavailable',
      undefined,
      retryAfter ? { 'Retry-After': retryAfter } : undefined
    );
  }
  if (res.status === 401) {
    throw new AppError(500, 'Voice service configuration error');
  }
  const text = await res.text();
  const snippet = text.length > 800 ? `${text.slice(0, 800)}…` : text;
  const status =
    res.status >= 400 && res.status < 500
      ? 400
      : 502;
  throw new AppError(status, `ElevenLabs ${context} failed`, { status: res.status, body: snippet });
}

export async function addVoiceFromSample(params: {
  name: string;
  description: string;
  buffer: Buffer;
  filename: string;
  mimeType: string;
}): Promise<{ voice_id: string }> {
  const form = new FormData();
  form.append('name', params.name);
  form.append('description', params.description);
  form.append(
    'files',
    new Blob([new Uint8Array(params.buffer)], { type: params.mimeType }),
    params.filename
  );

  const res = await fetch(`${BASE}/voices/add`, {
    method: 'POST',
    headers: { 'xi-api-key': config.elevenLabsApiKey },
    body: form,
  });

  if (!res.ok) {
    await handleElevenLabsFailure(res, 'voices/add');
  }

  const json = (await res.json()) as { voice_id?: string };
  if (!json.voice_id) {
    throw new AppError(502, 'Invalid ElevenLabs response: missing voice_id');
  }
  return { voice_id: json.voice_id };
}

export async function deleteVoice(voiceId: string): Promise<void> {
  const res = await fetch(`${BASE}/voices/${encodeURIComponent(voiceId)}`, {
    method: 'DELETE',
    headers: { 'xi-api-key': config.elevenLabsApiKey },
  });

  if (res.status === 404) {
    return;
  }
  if (!res.ok) {
    await handleElevenLabsFailure(res, 'voices/delete');
  }
}

export async function synthesizeSpeech(
  voiceId: string,
  text: string
): Promise<Response> {
  const res = await fetch(
    `${BASE}/text-to-speech/${encodeURIComponent(voiceId)}`,
    {
      method: 'POST',
      headers: {
        'xi-api-key': config.elevenLabsApiKey,
        Accept: 'audio/mpeg',
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        text,
        model_id: 'eleven_flash_v2_5',
        voice_settings: {
          stability: 0.5,
          similarity_boost: 0.8,
          style: 0.0,
          use_speaker_boost: true,
        },
      }),
    }
  );

  if (!res.ok) {
    await handleElevenLabsFailure(res, 'text-to-speech');
  }

  return res;
}
