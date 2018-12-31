using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[RequireComponent(typeof(SpriteRenderer))]
public class directionScale : MonoBehaviour {

    [SerializeField]
    Transform _Pivot;
    SpriteRenderer spriteRender;
    private void Start()
    {
        spriteRender = GetComponent<SpriteRenderer>();
    }
    // Update is called once per frame
    void Update () {
        spriteRender.material.SetVector("_Pivot",new Vector4(_Pivot.position.x, _Pivot.position.y, 0,0));
    }
}
