import React from 'react';
import { useForm } from '@inertiajs/react';

export const Signin = () => {
  const { data, post, setData, processing, errors } = useForm({
    email: '',
  });

  const submit = (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();

    post('/signin');
  };

  return (
    <div className="w-screen h-screen">
      <form onSubmit={submit} className="flex flex-col w-full items-center justify-center h-full">
        <input
          type="text"
          value={data.email}
          onChange={e => setData('email', e.target.value)}
          className="ring ring-primary-500 rounded-md p-2 mb-4"
        />
        {errors.email && <div>{errors.email}</div>}
        <button type="submit" disabled={processing}>
          Sign In
        </button>
      </form>
    </div>
  );
};
