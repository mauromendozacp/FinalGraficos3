using UnityEngine;

public class InputMouse : MonoBehaviour
{
    [SerializeField] private SpriteRenderer plasmaSprite = null;

    private void Update()
    {
        UpdateInput();
    }

    private void UpdateInput()
    {
        if (Input.GetMouseButton(0))
        {
            Vector2 mousePos = Camera.main.ScreenToWorldPoint(Input.mousePosition);
            plasmaSprite.material.SetFloat("_MouseX", mousePos.x);
            plasmaSprite.material.SetFloat("_MouseY", mousePos.y);
        }

        if (Input.GetMouseButtonUp(0))
        {
            plasmaSprite.material.SetFloat("_MouseX", 0);
            plasmaSprite.material.SetFloat("_MouseY", 0);
        }
    }
}
