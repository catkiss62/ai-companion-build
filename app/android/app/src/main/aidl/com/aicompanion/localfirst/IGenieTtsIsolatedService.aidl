package com.aicompanion.localfirst;

interface IGenieTtsIsolatedService {
    String statusJson();
    String verifyArtifactsJson();
    String initializeJson(String language);
    String prepareLanguageJson(String language);
    String importChineseRobertaJson(String path);
    String generateToFile(String text, String language, String voice, double speed);
    void stop();
    void releaseRuntime();
}
