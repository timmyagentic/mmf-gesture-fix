import Foundation
let policyOK = runPolicyTests(), languageOK = runLanguageTests()
exit(policyOK && languageOK ? 0 : 1)
