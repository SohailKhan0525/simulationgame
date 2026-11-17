using UnityEngine;

namespace Qofeno
{
    public static partial class ShopModels
    {
        static readonly Mesh[] BasketMeshes = new Mesh[2];

        internal static Transform Handbasket(Transform parent, bool carried)
        {
            int model=carried ? 1 : 0;
            if (!BasketMeshes[model]) BasketMeshes[model]=BuildBasket(carried);
            if (!material) material=PrintAtlas.Material();
            var basket=new GameObject("Slotted market basket");
            basket.transform.SetParent(parent,false);
            basket.AddComponent<MeshFilter>().sharedMesh=BasketMeshes[model];
            basket.AddComponent<MeshRenderer>().sharedMaterial=material;
            return basket.transform;
        }

        static Mesh BuildBasket(bool carried)
        {
            var m=new Builder();
            m.Box(V(0,.008f,0),V(.22f,.016f,.29f),Ink.Pine,.014f);
            // The mould has open ventilation slots between the ribs; the upper lip takes the handle loads.
            for(int i=0;i<3;i++)
            {
                float t=i*.5f, y=.039f+t*.128f, x=.115f+t*.022f, z=.149f+t*.023f;
                Ink band=i==2 ? Ink.Sage : Ink.Pine;
                foreach(int side in new[]{-1,1})
                {
                    m.Box(V(side*x,y,0),V(.015f,.017f,2*z),band,.003f);
                    m.Box(V(0,y,side*z),V(2*x,.017f,.015f),band,.003f);
                }
            }
            foreach(int side in new[]{-1,1})
            {
                for(int i=-2;i<=2;i++)
                    m.Taper(V(side*.111f,.014f,i*.068f),.005f,.008f,
                        V(side*.136f,.162f,i*.080f),.006f,.009f,Ink.Pine);
                for(int i=-2;i<=2;i++)
                    m.Taper(V(i*.051f,.014f,side*.147f),.007f,.005f,
                        V(i*.062f,.162f,side*.173f),.008f,.006f,Ink.Pine);
                if (carried)
                {
                    m.Taper(V(0,.169f,side*.167f),.0055f,.0055f,
                        V(-.085f,.304f,side*.067f),.0055f,.0055f,Ink.Steel);
                }
                else
                {
                    m.Box(V(side*.119f,.178f,0),V(.009f,.009f,.31f),Ink.Steel,.002f);
                }
            }
            if(carried) m.Box(V(-.085f,.304f,0),V(.017f,.017f,.147f),Ink.Honey,.005f);
            m.Box(V(0,.119f,-.166f),V(.117f,.050f,.012f),Ink.Bone,.007f);
            m.Box(V(0,.119f,-.174f),V(.083f,.014f,.005f),Ink.Pine);
            return m.Finish(carried ? "Handbasket raised handle" : "Nesting handbasket");
        }
    }
}
