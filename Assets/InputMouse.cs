using UnityEngine;

public class InputMouse : MonoBehaviour
{
    [SerializeField] private SpriteRenderer plasmaSprite = null;

    private Vector2 mousePos = Vector2.zero;

    private void Update()
    {
        mousePos = Camera.main.ScreenToWorldPoint(Input.mousePosition);

        UpdateInputCastRay();
        UpdateInputMoveCamera();
    }

    private void UpdateInputCastRay()
    {
        if (Input.GetMouseButton(0))
        {
            plasmaSprite.material.SetFloat("_MouseX", mousePos.x);
            plasmaSprite.material.SetFloat("_MouseY", mousePos.y);
            plasmaSprite.material.SetInt("_EnableCast", 1);
        }

        if (Input.GetMouseButtonUp(0))
        {
            plasmaSprite.material.SetFloat("_MouseX", 0);
            plasmaSprite.material.SetFloat("_MouseY", 0);
            plasmaSprite.material.SetInt("_EnableCast", 0);
        }
    }

    private void UpdateInputMoveCamera()
    {
        if (Input.GetMouseButton(1))
        {
            plasmaSprite.material.SetFloat("_PosX", mousePos.x);
            plasmaSprite.material.SetFloat("_PosY", mousePos.y);
            plasmaSprite.material.SetInt("_EnableMoveCamera", 1);
        }

        if (Input.GetMouseButtonUp(1))
        {
            plasmaSprite.material.SetFloat("_PosX", 0);
            plasmaSprite.material.SetFloat("_PosY", 0);
            plasmaSprite.material.SetInt("_EnableMoveCamera", 0);
        }
    }
}
