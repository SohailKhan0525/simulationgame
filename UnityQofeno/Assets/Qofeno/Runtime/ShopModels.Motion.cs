using UnityEngine;

namespace Qofeno
{
    public static partial class ShopModels
    {
        /// <summary>The lower third of the modeled checkout screen, facing the customer at -Z.</summary>
        public static TextMesh CreateTillReadout(Transform checkout, HarborBlock block)
        {
            var result = new GameObject("Register amount").AddComponent<TextMesh>();
            result.transform.SetParent(checkout, false);
            result.transform.localPosition = V(.51f, 1.184f, .1215f);
            block.ApplyWorldFont(result);
            result.fontSize = 64;
            result.characterSize = .008f;
            result.anchor = TextAnchor.MiddleCenter;
            result.alignment = TextAlignment.Center;
            result.color = new Color32(231, 236, 203, 255);
            result.text = "READY";
            return result;
        }

        /// <summary>Prepare rigid articulated limbs once. Static display instances still use a single mesh.</summary>
        public static WalkCycle ArticulateCustomer(Transform customer) => new WalkCycle(customer);

        public sealed class WalkCycle
        {
            private static readonly Mesh[] Sections = new Mesh[8];
            private readonly Transform figure;
            private readonly Transform leftThigh, rightThigh, leftShin, rightShin, leftArm, rightArm;
            internal WalkCycle(Transform customer)
            {
                customer.GetComponent<MeshRenderer>().enabled = false;
                figure = new GameObject("Walking figure").transform;
                figure.SetParent(customer, false);
                Attach(BodyPart.Torso, figure, Vector3.zero, Vector3.zero);
                var leftHip = V(-.105f,.82f,0);
                var rightHip = V(.105f,.82f,0);
                leftThigh = Attach(BodyPart.LeftThigh, figure, leftHip, Vector3.zero);
                rightThigh = Attach(BodyPart.RightThigh, figure, rightHip, Vector3.zero);
                leftShin = Attach(BodyPart.LeftShin, leftThigh, V(-.106f,.457f,0), leftHip);
                rightShin = Attach(BodyPart.RightShin, rightThigh, V(.106f,.457f,0), rightHip);
                leftArm = Attach(BodyPart.LeftArm, figure, V(-.213f,1.32f,0), Vector3.zero);
                rightArm = Attach(BodyPart.RightArm, figure, V(.213f,1.32f,0), Vector3.zero);
            }
            private static Transform Attach(BodyPart id,Transform parent,Vector3 pivot,Vector3 parentPivot)
            {
                int index = (int)id;
                if (!Sections[index])
                {
                    var shape = new Builder(id, pivot);
                    BuildCustomer(shape);
                    Sections[index] = shape.Finish("Harbor shopper " + id);
                }
                var section = new GameObject(id.ToString());
                section.transform.SetParent(parent, false);
                section.transform.localPosition = pivot - parentPivot;
                section.AddComponent<MeshFilter>().sharedMesh = Sections[index];
                section.AddComponent<MeshRenderer>().sharedMaterial = material;
                return section.transform;
            }
            /// <param name="phaseRadians">Continuous phase; +2π is two footfalls.</param>
            /// <param name="strength01">Zero restores the neutral pose exactly.</param>
            public void Step(float phaseRadians, float strength01)
            {
                float strength = Mathf.Clamp01(strength01);
                float swing = Mathf.Sin(phaseRadians);
                float lift = Mathf.Cos(phaseRadians);
                float legs = 22f * swing * strength;
                leftThigh.localRotation = Quaternion.Euler(legs, 0, 0);
                rightThigh.localRotation = Quaternion.Euler(-legs, 0, 0);
                leftShin.localRotation = Quaternion.Euler(-32f * Mathf.Max(0, lift) * strength, 0, 0);
                rightShin.localRotation = Quaternion.Euler(-32f * Mathf.Max(0, -lift) * strength, 0, 0);
                float arms = 17f * swing * strength;
                leftArm.localRotation = Quaternion.Euler(-arms, 0, 0);
                rightArm.localRotation = Quaternion.Euler(arms, 0, 0);
                figure.localPosition = V(0, -.035f * swing * swing * strength, 0);
            }
        }
    }
}
