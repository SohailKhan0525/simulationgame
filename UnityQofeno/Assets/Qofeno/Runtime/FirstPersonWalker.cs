using UnityEngine;
using UnityEngine.EventSystems;

namespace Qofeno
{
    public sealed class FirstPersonWalker : MonoBehaviour
    {
        const float EyeHeight = 1.57f;
        const float FocusSeconds = .26f;
        public CharacterController Controller { get; private set; }
        public Transform View { get; private set; }
        public bool AtDesk => focusProgress >= 1f;
        public float Yaw => yaw;
        public float Pitch => pitch;
        float yaw, pitch = 5, verticalSpeed, focusProgress;
        bool aimingAtDesk, mouseLook;
        int walkFinger = -1, lookFinger = -1;
        Vector2 walkStart, walkAxis;
        Vector3 savedEye;
        Quaternion savedFacing;

        public void Place(Vector3 spawn, float startYaw = 0, float startPitch = 5)
        {
            yaw = startYaw;
            pitch = Mathf.Clamp(startPitch, -70, 70);
            transform.rotation = Quaternion.Euler(0, yaw, 0);
            transform.position = spawn + Vector3.up * .04f;
            Controller = gameObject.AddComponent<CharacterController>();
            Controller.height = 1.72f; Controller.radius = .25f;
            Controller.center = Vector3.up * .86f;
            Controller.stepOffset = .17f; Controller.skinWidth = .025f;
            var cam = new GameObject("Shopkeeper view", typeof(Camera), typeof(AudioListener)).GetComponent<Camera>();
            cam.tag = "MainCamera";
            cam.transform.SetParent(transform, false);
            cam.transform.localPosition = Vector3.up * EyeHeight;
            cam.transform.localRotation = Quaternion.Euler(pitch, 0, 0);
            cam.fieldOfView = 62; cam.nearClipPlane = .045f; cam.farClipPlane = 95;
            View = cam.transform;
            Input.multiTouchEnabled = true;
        }

        public void DeskMode(bool active)
        {
            if (active && !aimingAtDesk)
            {
                savedEye = View.position;
                savedFacing = View.rotation;
            }
            aimingAtDesk = active;
            ClearInput();
        }

        void ClearInput()
        {
            walkFinger = lookFinger = -1;
            walkAxis = Vector2.zero;
            mouseLook = false;
        }

        public void Tick(float dt, bool menu)
        {
            if (aimingAtDesk || focusProgress > 0)
            {
                focusProgress = Mathf.MoveTowards(focusProgress, aimingAtDesk ? 1 : 0, Time.unscaledDeltaTime / FocusSeconds);
                float smooth = Mathf.SmoothStep(0, 1, focusProgress);
                Vector3 screen = HarborBlock.DeskPosition + Vector3.up * 1.29f;
                Vector3 eye = screen + new Vector3(-.73f, .10f, 0);
                View.SetPositionAndRotation(Vector3.Lerp(savedEye, eye, smooth),
                    Quaternion.Slerp(savedFacing, Quaternion.LookRotation(screen - eye), smooth));
                return;
            }
            if (menu) return;
            Vector2 movement = Vector2.zero, look = Vector2.zero;
            if (Input.touchCount > 0 || walkFinger >= 0 || lookFinger >= 0)
            {
                ReadTouches(out look);
                movement = walkAxis;
            }
            else
            {
                movement.x = (Input.GetKey(KeyCode.D) || Input.GetKey(KeyCode.RightArrow) ? 1 : 0) -
                             (Input.GetKey(KeyCode.A) || Input.GetKey(KeyCode.LeftArrow) ? 1 : 0);
                movement.y = (Input.GetKey(KeyCode.W) || Input.GetKey(KeyCode.UpArrow) ? 1 : 0) -
                             (Input.GetKey(KeyCode.S) || Input.GetKey(KeyCode.DownArrow) ? 1 : 0);
                if (Input.GetMouseButtonDown(0) || Input.GetMouseButtonDown(1))
                    mouseLook = EventSystem.current == null || !EventSystem.current.IsPointerOverGameObject();
                if (!Input.GetMouseButton(0) && !Input.GetMouseButton(1)) mouseLook = false;
                if (mouseLook) look = new Vector2(Input.GetAxisRaw("Mouse X"), Input.GetAxisRaw("Mouse Y")) * 2.7f;
            }
            yaw += look.x;
            pitch = Mathf.Clamp(pitch - look.y, -70, 70);
            transform.rotation = Quaternion.Euler(0, yaw, 0);
            View.localRotation = Quaternion.Euler(pitch, 0, 0);
            movement = Vector2.ClampMagnitude(movement, 1);
            Vector3 velocity = (transform.forward * movement.y + transform.right * movement.x) * 2.5f;
            verticalSpeed = Controller.isGrounded ? -1.5f : Mathf.Max(-15f, verticalSpeed - 19f * dt);
            velocity.y = verticalSpeed;
            Controller.Move(velocity * dt);
            if (transform.position.y < -3f)
            {
                Controller.enabled = false;
                transform.position = HarborBlock.Spawn + Vector3.up * .05f;
                Controller.enabled = true;
                verticalSpeed = 0;
            }
        }

        void ReadTouches(out Vector2 look)
        {
            look = Vector2.zero;
            if (Input.touchCount == 0) { ClearInput(); return; }
            Rect area = Screen.safeArea;
            float width = Mathf.Max(1, area.width), height = Mathf.Max(1, area.height);
            for (int i = 0; i < Input.touchCount; i++)
            {
                Touch touch = Input.GetTouch(i);
                int id = touch.fingerId;
                if (touch.phase == TouchPhase.Began)
                {
                    if (EventSystem.current != null && EventSystem.current.IsPointerOverGameObject(id)) continue;
                    if (touch.position.x < area.xMin + width * .46f && walkFinger < 0)
                    {
                        walkFinger = id; walkStart = touch.position;
                    }
                    else if (touch.position.x >= area.xMin + width * .46f && lookFinger < 0) lookFinger = id;
                }
                if (touch.phase == TouchPhase.Ended || touch.phase == TouchPhase.Canceled)
                {
                    if (id == walkFinger) { walkFinger = -1; walkAxis = Vector2.zero; }
                    if (id == lookFinger) lookFinger = -1;
                    continue;
                }
                if (id == walkFinger)
                {
                    var offset = (touch.position - walkStart) / (height * .12f);
                    float radius = Mathf.Clamp01((offset.magnitude - .10f) / .90f);
                    walkAxis = offset.normalized * radius;
                }
                if (id == lookFinger) look += touch.deltaPosition * (87f / height);
            }
        }

        void OnApplicationFocus(bool focused) { if (!focused) ClearInput(); }
    }
}
