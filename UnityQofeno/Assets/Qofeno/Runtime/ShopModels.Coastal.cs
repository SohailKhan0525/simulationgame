using System;
using UnityEngine;

namespace Qofeno
{
    public static partial class ShopModels
    {
        public const string CoastalPrints = "ShopModels/coastal-prints";
        static readonly Mesh[] coastalMeshes = new Mesh[3];
        static Material coastalMaterial;

        public static Rect CoastalLabelUV(int sku)
        {
            if (sku < 3 || sku > 5) throw new ArgumentOutOfRangeException(nameof(sku));
            // Each printed panel has a half-texel inset and a same-ink bleed at its edges.
            return new Rect((20.5f + (sku - 3) * 348f) / 1024f, 136.5f / 512f,
                287f / 1024f, 367f / 512f);
        }

        public static GameObject CoastalProduct(Transform parent, int sku)
        {
            if (sku < 3 || sku > 5) throw new ArgumentOutOfRangeException(nameof(sku));
            int index = sku - 3;
            if (!coastalMaterial)
            {
                coastalMaterial = CreateSurfaceMaterial("Coastal grocery packaging");
                coastalMaterial.mainTexture = Resources.Load<Texture2D>(CoastalPrints);
                coastalMaterial.SetFloat("_Glossiness", .19f);
            }
            if (!coastalMeshes[index])
            {
                var pack = new Builder();
                switch (sku)
                {
                    case 3: BuildOatSack(pack); break;
                    case 4: BuildRoastPouch(pack); break;
                    case 5: BuildTomatoTin(pack); break;
                }
                coastalMeshes[index] = pack.Finish(RetailShift.NameOf(sku));
            }
            var product = new GameObject(RetailShift.NameOf(sku));
            product.transform.SetParent(parent, false);
            product.AddComponent<MeshFilter>().sharedMesh = coastalMeshes[index];
            product.AddComponent<MeshRenderer>().sharedMaterial = coastalMaterial;
            return product;
        }

        static void BuildOatSack(Builder pack)
        {
            // A paper gusset lets the bag stand; the broad shoulders pinch into the rolled top.
            pack.Taper(V(0,0,0), .075f,.032f, V(0,.034f,0), .093f,.050f, Ink.Flax);
            pack.Taper(V(0,.034f,0), .093f,.050f, V(0,.225f,0), .093f,.050f, Ink.Flax);
            pack.Taper(V(0,.225f,0), .093f,.050f, V(.002f,.270f,.004f), .076f,.009f, Ink.Flax);
            pack.Box(V(.002f,.273f,.005f),V(.158f,.012f,.022f),Ink.Honey,.003f);
            pack.Box(V(.002f,.268f,-.005f),V(.150f,.004f,.005f),Ink.Flax);
            pack.Front(V(0,.130f,-.0506f),.144f,.184f,CoastalLabelUV(3));
        }

        static void BuildRoastPouch(Builder pack)
        {
            // Flat foil front, folded back seam and a heat-crimped fin above the side gussets.
            pack.Taper(V(0,0,0),.065f,.032f,V(0,.019f,0),.077f,.042f,Ink.Navy);
            pack.Box(V(0,.103f,0),V(.154f,.170f,.084f),Ink.Navy,.008f);
            pack.Taper(V(0,.187f,0),.077f,.042f,V(0,.222f,.009f),.071f,.005f,Ink.Navy);
            pack.Box(V(0,.227f,.009f),V(.154f,.014f,.010f),Ink.Sage,.002f);
            for (int i = 0; i < 12; i++)
                pack.Box(V(-.066f+i*.012f,.227f,.0034f),V(.002f,.009f,.001f),Ink.Pine);
            pack.Box(V(.022f,.107f,.043f),V(.013f,.166f,.004f),Ink.Slate);
            pack.Front(V(0,.104f,-.0426f),.1235f,.158f,CoastalLabelUV(4));
        }

        static void BuildTomatoTin(Builder pack)
        {
            const int sides = 24;
            pack.Cylinder(V(0,.075f,0),.063f,.063f,.142f,Ink.Brick,sides);
            pack.Cylinder(V(0,.004f,0),.065f,.065f,.008f,Ink.Steel,sides);
            pack.Cylinder(V(0,.148f,0),.065f,.065f,.008f,Ink.Pearl,sides);
            pack.Sleeve(.0636f,.010f,.142f,54f,CoastalLabelUV(5),12);
            // Pressed concentric lid and a riveted ring pull in relief.
            pack.Cylinder(V(0,.152f,0),.058f,.058f,.002f,Ink.Slate,sides);
            pack.Cylinder(V(0,.153f,0),.055f,.055f,.002f,Ink.Steel,sides);
            pack.Cylinder(V(0,.154f,-.012f),.013f,.022f,.003f,Ink.Pearl,16);
            pack.Cylinder(V(0,.156f,-.016f),.0075f,.010f,.001f,Ink.Slate,12);
            pack.Cylinder(V(0,.156f,.002f),.004f,.004f,.002f,Ink.Steel,10);
        }
    }
}
