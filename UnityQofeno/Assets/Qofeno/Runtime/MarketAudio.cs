using UnityEngine;

namespace Qofeno
{
    public sealed class MarketAudio : MonoBehaviour
    {
        AudioSource output;
        AudioClip scan, paid, stock;

        void Awake()
        {
            output = gameObject.AddComponent<AudioSource>();
            output.playOnAwake = false;
            scan = Make("Scanner", 1260, 1260, .08f);
            paid = Make("Payment accepted", 740, 990, .19f);
            stock = Make("Carton set down", 145, 90, .085f);
        }

        static AudioClip Make(string title, float low, float high, float length)
        {
            const int rate = 22050;
            int count = Mathf.CeilToInt(rate * length);
            var data = new float[count];
            float phase = 0;
            for (int i = 0; i < count; i++)
            {
                float progress = (float)i / count;
                float frequency = progress < .46f ? low : high;
                phase += frequency * 2f * Mathf.PI / rate;
                float envelope = Mathf.Min(1f, progress * 30f) * (1f - progress);
                data[i] = Mathf.Sin(phase) * envelope * .16f;
            }
            var clip = AudioClip.Create(title, count, 1, rate, false);
            clip.SetData(data, 0);
            return clip;
        }

        public void Scan() => output.PlayOneShot(scan);
        public void Paid() => output.PlayOneShot(paid);
        public void Stock() => output.PlayOneShot(stock);
        void OnDestroy()
        {
            Destroy(scan); Destroy(paid); Destroy(stock);
        }
    }
}
