import { type FormHTMLAttributes, type PropsWithChildren } from "react"

type Props = FormHTMLAttributes<HTMLFormElement> & PropsWithChildren

const Form = ({ children, ...props }: Props) => (
  <form
    className="z-10 flex w-[calc(100%-2rem)] max-w-sm flex-col gap-4 rounded-md bg-white p-4 shadow-sm sm:w-full sm:p-5"
    {...props}
  >
    {children}
  </form>
)

export default Form
