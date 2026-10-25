using System.Collections;
using UnityEngine;
using UnityEngine.SceneManagement;

/// <summary>
/// Owns the run's lifecycle. For now a run ends only by dying, and a new run
/// starts by reloading the current scene after a short pause (Story 002).
/// </summary>
public class RunController : MonoBehaviour
{
    [SerializeField, Min(0f)] private float _restartDelay = 1.5f;

    private bool _ending;

    /// <summary>Ends the run and starts a new one after the restart delay. Repeated calls are ignored.</summary>
    public void EndRun()
    {
        if (_ending) return;
        _ending = true;
        StartCoroutine(RestartAfterDelay());
    }

    private IEnumerator RestartAfterDelay()
    {
        yield return new WaitForSeconds(_restartDelay);
        SceneManager.LoadScene(SceneManager.GetActiveScene().buildIndex);
    }
}
