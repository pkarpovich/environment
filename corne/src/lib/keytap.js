export const KEYTAP_URL = location.hostname.endsWith('.localhost')
  ? `${location.protocol}//corne-keytap.localhost`
  : `http://${location.hostname}:50501`

export function connectKeytap({ onPress, onRelease, onStatus }) {
  const source = new EventSource(KEYTAP_URL)

  source.onopen = () => onStatus('on')
  source.onerror = () => onStatus('off')
  source.onmessage = (event) => {
    const { code, edge, shift, char } = JSON.parse(event.data)
    if (edge === 'down') onPress(code, char, shift)
    else onRelease(code, shift)
  }

  return () => source.close()
}
