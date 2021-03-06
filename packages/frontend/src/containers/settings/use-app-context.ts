import { useRouter } from 'next/router'
import { createContainer } from 'unstated-next'
import { useEffect } from 'react'
import { useCurrentState } from '@zeit-ui/react'

const DEFAULT_LOCALE = 'en'
const DEFAULT_TAB = 'dashboard'

const useAppContext = ({ themeChangeHandler }) => {
  const { pathname } = useRouter()
  const [locale, setLocale, localeRef] = useCurrentState<string>(DEFAULT_LOCALE)
  const [tabbar, setTab, tabRef] = useCurrentState<string>(DEFAULT_TAB)

  useEffect(() => {
    const names = pathname.split('/').filter((r) => !!r)
    const currentLocale = names[0] || DEFAULT_LOCALE
    const currentTabbar = names[1] || DEFAULT_TAB

    if (currentLocale !== localeRef.current) {
      setLocale(currentLocale)
    }

    if (currentTabbar !== tabRef.current) {
      setTab(currentTabbar)
    }
  }, [pathname])

  return {
    locale,
    tabbar,
    themeChangeHandler,
  }
}

export default createContainer(useAppContext)
