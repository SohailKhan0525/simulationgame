using System;
using UnityEngine;

namespace Qofeno
{
    /// A second visitor can browse and wait while the first visitor pays.
    public sealed class HarborQueue
    {
        [Serializable]
        public sealed class Snapshot
        {
            public int visitorNumber;
            public float elapsed;
        }

        const float EntryDelay = 2.5f;
        const float WalkSpeed = 1.15f;
        const float BrowseTime = 1.4f;
        const int ShelfStop = 2;
        static readonly Vector3[] Route =
        {
            new Vector3(-.70f, 0, -4.15f),
            new Vector3(-.70f, 0, -.86f),
            new Vector3(-1.76f, 0, 1.63f),
            new Vector3(-.74f, 0, 1.48f),
            new Vector3(-.74f, 0, 3.32f),
            new Vector3(.48f, 0, 3.36f),
            new Vector3(1.93f, 0, 3.86f)
        };

        // Positions stay clear of both checkout ends, the annex shelf and the wrapping bench.
        static readonly float[] Arrivals = MakeTimetable();
        static float ReadyTime => Arrivals[Arrivals.Length - 1] + .65f;

        readonly Transform customer;
        readonly ShopModels.WalkCycle gait;
        float entryDelay = EntryDelay, elapsed;
        int visitorNumber;

        public bool Occupied => customer.gameObject.activeSelf;
        public bool Ready => Occupied && elapsed >= ReadyTime;

        public static HarborQueue Build(Transform parent) => new HarborQueue(parent);

        HarborQueue(Transform parent)
        {
            customer = ShopModels.Customer(parent).transform;
            customer.name = "Waiting shopper";
            gait = ShopModels.ArticulateCustomer(customer);
            var body = customer.gameObject.AddComponent<Rigidbody>();
            body.isKinematic = true;
            body.useGravity = false;
            var capsule = customer.gameObject.AddComponent<CapsuleCollider>();
            capsule.center = new Vector3(0, .81f, 0);
            capsule.height = 1.6f;
            capsule.radius = .21f;
            customer.gameObject.SetActive(false);
        }

        static float[] MakeTimetable()
        {
            var arrivals = new float[Route.Length];
            for (int i = 1; i < Route.Length; i++)
                arrivals[i] = Departure(arrivals, i - 1) + Vector3.Distance(Route[i - 1], Route[i]) / WalkSpeed;
            return arrivals;
        }

        static float Departure(float[] arrivals, int stop) => arrivals[stop] + (stop == ShelfStop ? BrowseTime : 0f);

        public void Tick(float dt, bool allowNew, bool checkoutBusy, int visitorSeed)
        {
            if (dt <= 0 || Ready) return;
            if (!Occupied)
            {
                if (!allowNew || !checkoutBusy)
                {
                    entryDelay = EntryDelay;
                    return;
                }
                entryDelay -= dt;
                if (entryDelay > 0) return;
                Admit(visitorSeed, 0);
            }
            elapsed = Mathf.Min(elapsed + dt, ReadyTime);
            Pose(dt, false);
        }

        void Admit(int seed, float time)
        {
            visitorNumber = seed;
            elapsed = time;
            gait.SetAppearance(seed);
            Pose(0, true);
            customer.gameObject.SetActive(true);
        }

        void Pose(float dt, bool snap)
        {
            Vector3 position = Route[Route.Length - 1];
            Quaternion facing = Quaternion.identity; // Models look along local -Z, toward the register here.
            bool walking = false;
            for (int i = 1; i < Route.Length; i++)
            {
                if (elapsed > Arrivals[i]) continue;
                float start = Departure(Arrivals, i - 1);
                float progress = Mathf.InverseLerp(start, Arrivals[i], elapsed);
                position = Vector3.Lerp(Route[i - 1], Route[i], progress);
                walking = elapsed >= start;
                facing = walking ? Quaternion.LookRotation(Route[i - 1] - Route[i]) : Quaternion.LookRotation(Vector3.back);
                break;
            }

            customer.localPosition = position;
            customer.localRotation = snap ? facing : Quaternion.RotateTowards(customer.localRotation, facing, dt * 300f);
            gait.Step(elapsed * 6.25f, walking ? .92f : 0);
        }

        // The session reserves stock once after this handoff. This visitor holds no merchandise.
        public bool TryTake(out Vector3 worldPosition, out int seed)
        {
            worldPosition = customer.position;
            seed = visitorNumber;
            if (!Ready) return false;
            customer.gameObject.SetActive(false);
            entryDelay = EntryDelay;
            return true;
        }

        public Snapshot Capture() => Occupied ? new Snapshot { visitorNumber = visitorNumber, elapsed = elapsed } : null;

        public void Restore(Snapshot snapshot)
        {
            // JsonUtility may deserialize an absent inline record as an all-zero object.
            if (snapshot == null || snapshot.visitorNumber <= 0 || !(snapshot.elapsed >= 0 && snapshot.elapsed <= ReadyTime)) return;
            Admit(snapshot.visitorNumber, snapshot.elapsed);
        }
    }
}
