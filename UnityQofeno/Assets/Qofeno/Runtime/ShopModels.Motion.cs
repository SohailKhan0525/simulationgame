using UnityEngine;

namespace Qofeno
{
    public static partial class ShopModels
    {
        static Mesh palletMesh;

        internal static GameObject CoastalPallet(Transform parent)
        {
            if (!palletMesh)
            {
                var m = new Builder();
                for (int z=-1; z<=1; z++)
                    m.Box(V(0,.009f,z*.76f),V(.66f,.018f,.11f),Ink.Leather,.004f);
                for (int slat=0; slat<5; slat++)
                    m.Box(V((slat-2)*.14f,.028f,0),V(.129f,.021f,2.12f),slat%2==0 ? Ink.Flax : Ink.Honey,.004f);
                for(int edge=-1;edge<=1;edge+=2)
                    m.Box(V(.273f,.040f,edge*.73f),V(.082f,.004f,.61f),Ink.Pine);
                m.Box(V(.273f,.040f,0),V(.082f,.004f,.55f),Ink.Pine);
                palletMesh=m.Finish("Coastal delivery pallet");
            }
            if (!material) material=PrintAtlas.Material();
            var pallet=new GameObject("Coastal receiving bays");
            pallet.transform.SetParent(parent,false);
            pallet.AddComponent<MeshFilter>().sharedMesh=palletMesh;
            pallet.AddComponent<MeshRenderer>().sharedMaterial=material;
            return pallet;
        }

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
            const int StaffAppearance = 3;
            static readonly Mesh[,] Sections = new Mesh[4, 8];
            readonly MeshFilter[] parts = new MeshFilter[8];
            readonly Transform basket;
            readonly Vector3[] bindPivots = new Vector3[8];
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
                basket = Handbasket(rightArm,true);
                basket.localPosition = V(.128f,-.82f,-.080f);
            }
            private Transform Attach(BodyPart id,Transform parent,Vector3 pivot,Vector3 parentPivot)
            {
                int index = (int)id;
                var section = new GameObject(id.ToString());
                section.transform.SetParent(parent, false);
                section.transform.localPosition = pivot - parentPivot;
                parts[index] = section.AddComponent<MeshFilter>();
                bindPivots[index] = pivot;
                parts[index].sharedMesh = Section(0, id, pivot);
                section.AddComponent<MeshRenderer>().sharedMaterial = material;
                return section.transform;
            }
            static Mesh Section(int appearance, BodyPart part, Vector3 pivot)
            {
                int index = (int)part;
                if (!Sections[appearance, index])
                {
                    var shape = new Builder(part, pivot);
                    BuildCustomer(shape, appearance);
                    Sections[appearance, index] = shape.Finish("Harbor figure " + appearance + " " + part);
                }
                return Sections[appearance, index];
            }

            public void SetAppearance(int visitIndex) => Dress(Mathf.Abs(visitIndex % 3));
            internal void DressForWork() => Dress(StaffAppearance);

            void Dress(int appearance)
            {
                foreach (BodyPart part in System.Enum.GetValues(typeof(BodyPart)))
                {
                    if (part == BodyPart.All) continue;
                    var filter = parts[(int)part];
                    filter.sharedMesh = Section(appearance, part, bindPivots[(int)part]);
                }
                basket.gameObject.SetActive(appearance != StaffAppearance);
                figure.localScale = Vector3.one * (appearance == 1 ? .95f : appearance == 2 ? 1.04f : 1f);
            }

            internal void HoldCase(float reach)
            {
                leftArm.localRotation = Quaternion.Euler(38f * reach, 0, 0);
                rightArm.localRotation = Quaternion.Euler(38f * reach, 0, 0);
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
