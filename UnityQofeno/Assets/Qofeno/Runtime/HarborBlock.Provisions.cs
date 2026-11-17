using System.Collections.Generic;
using UnityEngine;

namespace Qofeno
{
    public sealed partial class HarborBlock
    {
        public static readonly Vector3 SecondShelfPosition = new Vector3(-.92f, 0, 4.12f);
        static readonly Vector3 ReceivingStand = new Vector3(-4.53f, 0, -.37f);
        static readonly Vector3 PalletEnd = new Vector3(-4.53f, 0, 1.13f);
        static readonly Vector3 ShelfStand = new Vector3(-3.55f, 0, 1.96f);
        readonly Dictionary<Transform, TextMesh[]> shelfTickets = new Dictionary<Transform, TextMesh[]>();

        Transform stocker, workCase, receivingExtension;
        bool clearedPallet;
        ShopModels.WalkCycle stockerGait;
        enum RestockPhase { Waiting, Lifting, Carrying, Placing, Returning }
        RestockPhase restockPhase;
        float workPause, workStride;

        void DressMarket()
        {
            // Glazed tiles lift the service counter out of the timber-lined main sales floor.
            Box(slate, 2.42f, 1.51f, 4.579f, 4.58f, 1.21f, .027f);
            for (int row = 0; row < 5; row++)
            {
                const float left = .13f, right = 4.71f, tileWidth = .51f;
                float start = left - (row % 2) * tileWidth * .5f;
                for (float x = start; x < right - .02f; x += tileWidth)
                {
                    float a = Mathf.Max(left, x), b = Mathf.Min(right, x + tileWidth);
                    Box(milk, (a + b) * .5f, 1.037f + row * .236f, 4.558f,
                        b - a - .009f, .226f, .025f);
                }
            }
            // Stockroom packing bench: folded paper bags, brass bag weights and the wrapping roll.
            Solid("Wrapping bench", wood, 3.57f, .91f, 4.10f, 2.13f, .075f, .74f);
            Box(marine, 3.57f, .47f, 4.16f, 1.93f, .84f, .54f);
            for (int i = 0; i < 3; i++)
            {
                float x = 2.96f + i * .62f;
                Box(milk, x, .62f, 3.88f, .58f, .39f, .027f);
                Box(brass, x, .71f, 3.851f, .16f, .026f, .039f);
            }
            for (int i = 0; i < 6; i++)
                Box(ochre, 3.32f + .014f * (i % 2), .963f + .022f * i, 4.03f, .38f, .019f, .49f);
            for (int i = 0; i < 3; i++)
            {
                float x = 3.76f + i * .24f, h = .26f + .047f * (i % 2);
                // The open bag has thin sides, a dark interior and folded side gussets.
                Box(ochre,x,.955f + h*.5f,4.033f,.221f,h,.014f);
                Box(ochre,x,.955f + h*.5f,4.177f,.221f,h,.014f);
                Box(wood,x-.104f,.955f+h*.49f,4.105f,.015f,h*.98f,.145f);
                Box(wood,x+.104f,.955f+h*.49f,4.105f,.015f,h*.98f,.145f);
                Box(marine,x,1.08f,4.021f,.076f,.04f,.009f);
            }
            var art = Finish("Harbor provision lithographs", "FFFFFF", .13f, "harbor-provision-prints");
            art.SetColor("_EmissionColor", new Color(.045f,.038f,.027f));
            Poster(art, -.87f, 1.61f, 0);
            Poster(art, 1.22f, 1.56f, 1);
            // Pendant shades use the same material batches as the original fittings.
            Pendant(1.24f, 1.51f);
            Pendant(2.38f, 1.51f);

            float bx = -1.94f, bz = -2.59f;
            Solid("Entrance basket stand", ink, bx, .095f, bz, .42f, .19f, .47f);
            Box(brass,bx,.19f,bz,.43f,.022f,.48f);
            for(int i=0;i<4;i++)
            {
                Transform basket=ShopModels.Handbasket(transform,false);
                basket.localPosition=new Vector3(bx,.20f+i*.050f,bz);
                basket.localEulerAngles=new Vector3(0,(i%2)*3f,0);
            }
        }

        void Poster(Material art, float x, float y, int panel)
        {
            const float width = 1.03f;
            Box(wood,x,y,4.512f,width+.085f,width+.085f,.065f);
            Box(brass,x,y,4.471f,width+.034f,width+.034f,.023f);
            GetBatch(art).Print(new Vector3(x,y,4.452f),Vector3.right*width,width,
                new Rect(panel*.5f+.001f,.002f,.498f,.996f));
        }

        void Pendant(float x, float z)
        {
            Barrel(ink,new Vector3(x,3.482f,z),.087f,.054f,12);
            Barrel(charcoal,new Vector3(x,3.245f,z),.011f,.45f,8);
            var top=new Vector3(x,3.018f,z);
            var bottom=top-Vector3.up*.182f;
            for (int i=0;i<18;i++)
            {
                float a=i*2*Mathf.PI/18, b=(i+1)*2*Mathf.PI/18;
                Vector3 u=new Vector3(Mathf.Cos(a),0,Mathf.Sin(a)), v=new Vector3(Mathf.Cos(b),0,Mathf.Sin(b));
                GetBatch(marine).Quad(bottom+u*.197f,top+u*.062f,top+v*.062f,bottom+v*.197f);
                GetBatch(milk).Quad(bottom+v*.194f,top+v*.057f,top+u*.057f,bottom+u*.194f);
                GetBatch(brass).Quad(bottom+u*.198f,bottom+v*.198f,bottom+v*.187f,bottom+u*.187f);
            }
            Barrel(lamp,bottom+Vector3.up*.020f,.070f,.066f,14);
        }

        void QuayStop()
        {
            // Public ferry landing opposite the shop. Keep the crossing and sightline to the boat clear.
            const float x = 1.82f, z = -16.72f;
            for (int side = -1; side <= 1; side += 2)
            {
                Solid("Shelter column",marine,x+side*1.57f,1.16f,z,.12f,2.32f,.12f);
                Box(brass,x+side*1.57f,.17f,z,.17f,.32f,.17f);
            }
            Box(marine,x,2.36f,z+.33f,3.52f,.12f,1.11f);
            Box(ink,x,2.25f,z+.86f,3.50f,.20f,.065f);
            Legend("EAST  QUAY   /   FERRY  LANDING",new Vector3(x,2.25f,z+.903f),180,.083f,Hex("F2E5BD"),true);
            for (int board=0;board<4;board++)
                Box(wood,x+.33f,.46f,z+.06f+board*.097f,1.78f,.065f,.082f);
            for(int board=0;board<3;board++)
                Box(wood,x+.33f,.59f+board*.11f,z+.035f,1.78f,.089f,.048f);
            for(int leg=-1;leg<=1;leg+=2)
                Box(ink,x+.33f+leg*.69f,.22f,z+.21f,.082f,.45f,.43f);
            Obstacle("Ferry bench",new Vector3(x+.33f,.37f,z+.19f),new Vector3(1.78f,.74f,.45f));
            Box(brass,x-.98f,1.47f,z,.62f,.79f,.069f);
            Box(milk,x-.98f,1.47f,z+.045f,.55f,.72f,.023f);
            Legend("CROSSINGS",new Vector3(x-.98f,1.71f,z+.061f),180,.060f,Hex("23493F"),true);
            for(int line=0;line<5;line++)
            {
                Box(slate,x-.98f,1.592f-line*.071f,z+.063f,.43f,.008f,.005f);
                Box(marine,x-1.07f,1.619f-line*.071f,z+.064f,.15f,.014f,.005f);
            }
        }

        public void SetReceivingExpanded(bool expanded)
        {
            if (expanded && !receivingExtension)
            {
                receivingExtension = ShopModels.CoastalPallet(transform).transform;
                receivingExtension.localPosition = new Vector3(-4.10f,0,DeliveryPosition.z);
                for (int bay=0;bay<3;bay++)
                {
                    var stamp=new GameObject("Coastal bay stencil").AddComponent<TextMesh>();
                    stamp.transform.SetParent(receivingExtension,false);
                    stamp.transform.localPosition=new Vector3(.27f,.045f,(bay-1)*.66f);
                    stamp.transform.localRotation=Quaternion.Euler(90,-90,0);
                    ApplyWorldFont(stamp);
                    stamp.fontSize=48;
                    stamp.characterSize=.009f;
                    stamp.anchor=TextAnchor.MiddleCenter;
                    stamp.color=Hex("FFEDC9");
                    stamp.text="C"+(bay+1);
                }
            }
            if (receivingExtension) receivingExtension.gameObject.SetActive(expanded);
        }

        public void UpdateShelfPrices(Transform shelf, int[] pence, int firstSku=0)
        {
            if (!shelfTickets.TryGetValue(shelf,out var tickets))
            {
                tickets = new TextMesh[3];
                shelfTickets.Add(shelf,tickets);
                for (int sku=0;sku<tickets.Length;sku++)
                {
                    var label = new GameObject("Shelf ticket").AddComponent<TextMesh>();
                    label.transform.SetParent(shelf,false);
                    var slot = ShopModels.ShelfSlot(sku*RetailShift.ShelfCapacity);
                    label.transform.localPosition = new Vector3(-.49f,slot.y-.034f,-.298f);
                    ApplyWorldFont(label);
                    label.fontSize=64;
                    label.characterSize=.0058f;
                    label.anchor=TextAnchor.MiddleCenter;
                    label.alignment=TextAlignment.Center;
                    label.color=Hex("153F34");
                    tickets[sku]=label;
                }
            }
            for(int sku=0;sku<tickets.Length;sku++)
                tickets[sku].text=RetailShift.NameOf(firstSku+sku)+"    "+MarketSession.Money(pence[firstSku+sku]);
        }

        public bool TickStocker(bool hired, bool hasWork, float dt)
        {
            if (!hired) return false;
            if (!stocker)
            {
                stocker = ShopModels.Customer(transform).transform;
                stocker.name = "Harbor stock clerk";
                stocker.localPosition = ReceivingStand;
                stocker.localRotation = Quaternion.Euler(0,-90f,0);
                stockerGait = ShopModels.ArticulateCustomer(stocker);
                stockerGait.DressForWork();
                workCase = ShopModels.Carton(stocker).transform;
                workCase.localPosition = new Vector3(0,.91f,-.29f);
                workCase.localScale = Vector3.one*.81f;
                workCase.gameObject.SetActive(false);
            }
            switch (restockPhase)
            {
                case RestockPhase.Waiting:
                    if (hasWork) { restockPhase=RestockPhase.Lifting; workPause=.9f; }
                    return false;
                case RestockPhase.Lifting:
                    workPause -= dt;
                    stockerGait.HoldCase(Mathf.Clamp01(1f - workPause));
                    if (workPause<=0)
                    {
                        workCase.gameObject.SetActive(true);
                        clearedPallet=false;
                        restockPhase=RestockPhase.Carrying;
                    }
                    return false;
                case RestockPhase.Carrying:
                    if (!clearedPallet)
                    {
                        clearedPallet=WalkTo(PalletEnd,true,dt);
                        return false;
                    }
                    if (WalkTo(ShelfStand,true,dt))
                    {
                        stocker.localRotation=Quaternion.Euler(0,-115f,0);
                        restockPhase=RestockPhase.Placing;
                        workPause=1.2f;
                    }
                    return false;
                case RestockPhase.Placing:
                    workPause-=dt;
                    if (workPause>0) return false;
                    workCase.gameObject.SetActive(false);
                    clearedPallet=false;
                    restockPhase=RestockPhase.Returning;
                    return true;
                case RestockPhase.Returning:
                    if (!clearedPallet)
                    {
                        clearedPallet=WalkTo(PalletEnd,false,dt);
                        return false;
                    }
                    if (WalkTo(ReceivingStand,false,dt))
                    {
                        stocker.localRotation=Quaternion.Euler(0,-90f,0);
                        restockPhase=RestockPhase.Waiting;
                    }
                    return false;
            }
            return false;
        }

        bool WalkTo(Vector3 target, bool carrying, float dt)
        {
            Vector3 delta=target-stocker.localPosition;
            if(delta.sqrMagnitude<.001f)
            {
                stockerGait.Step(0,0);
                if(carrying) stockerGait.HoldCase(1);
                return true;
            }
            stocker.localPosition=Vector3.MoveTowards(stocker.localPosition,target,dt*1.07f);
            stocker.localRotation=Quaternion.RotateTowards(stocker.localRotation,Quaternion.LookRotation(-delta),dt*295f);
            workStride+=dt*7.1f;
            stockerGait.Step(workStride,1);
            if(carrying) stockerGait.HoldCase(1);
            return false;
        }
    }
}
